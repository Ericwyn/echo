import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart' show Size;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/player/playback_contract.dart';
import '../design/layout/echo_desktop_metrics.dart';
import '../utils/logger.dart';
import 'desktop_close_settings.dart';
import 'desktop_tray_menu_state.dart';
import 'desktop_window_state_service.dart';
import 'status_notifier_host_tracker.dart';

const _exitCleanupTimeout = Duration(seconds: 4);
const _playerQuitTimeout = Duration(seconds: 15);
const _windowDestroyTimeout = Duration(seconds: 8);

/// Owns desktop window/tray lifetime only. Playback remains in PlayerNotifier.
class DesktopLifecycleService with WindowListener, TrayListener {
  DesktopLifecycleService._();

  static final DesktopLifecycleService instance = DesktopLifecycleService._();

  Future<void> Function()? _onTogglePlayPause;
  Future<void> Function()? _onPrevious;
  Future<void> Function()? _onNext;
  Future<void> Function()? _onQuit;
  Future<bool> Function()? _onBeforeQuit;
  Future<bool> Function({required bool trayAvailable})? _onBeforeHide;
  DBusClient? _sessionBusClient;
  StreamSubscription<DBusNameOwnerChangedEvent>? _watcherSubscription;
  final StatusNotifierHostTracker _statusNotifierHostTracker =
      StatusNotifierHostTracker();
  bool _initialized = false;
  bool _exitRequested = false;
  bool _trayIconRegistered = false;
  bool _trayAvailable = false;
  bool _windowHidden = false;
  bool _closeActionPending = false;
  bool _exitCheckInProgress = false;
  DesktopTrayMenuState _trayMenuState = const DesktopTrayMenuState.empty();

  bool get trayAvailable => _trayAvailable;

  Future<void> initialize({
    required Future<void> Function() onTogglePlayPause,
    required Future<void> Function() onPrevious,
    required Future<void> Function() onNext,
    required Future<void> Function() onQuit,
    required Future<bool> Function() onBeforeQuit,
    required Future<bool> Function({required bool trayAvailable}) onBeforeHide,
    required PlaybackSnapshot initialPlaybackSnapshot,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _onTogglePlayPause = onTogglePlayPause;
    _onPrevious = onPrevious;
    _onNext = onNext;
    _onQuit = onQuit;
    _onBeforeQuit = onBeforeQuit;
    _onBeforeHide = onBeforeHide;
    _trayMenuState = DesktopTrayMenuState.fromSnapshot(initialPlaybackSnapshot);

    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await windowManager.setTitle('Echoes');
      await windowManager.setMinimumSize(
        const Size(
          echoDesktopMinimumWindowWidth,
          echoDesktopMinimumWindowHeight,
        ),
      );
      Logger.infoWithTag(
        'DESKTOP',
        'minimum window size ${echoDesktopMinimumWindowWidth.toInt()}x${echoDesktopMinimumWindowHeight.toInt()}',
      );
      await windowManager.setPreventClose(true);
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'window lifecycle setup failed', error);
    }

    if (defaultTargetPlatform == TargetPlatform.linux) {
      await _connectToStatusNotifierWatcher();
    }
    await _installTrayIcon();
  }

  Future<void> updatePlaybackSnapshot(PlaybackSnapshot snapshot) async {
    if (_exitRequested) return;
    final nextState = DesktopTrayMenuState.fromSnapshot(snapshot);
    if (_trayMenuState == nextState) return;
    _trayMenuState = nextState;
    if (!_trayIconRegistered || !_trayAvailable) {
      return;
    }

    try {
      await trayManager.setContextMenu(_buildTrayContextMenu());
    } catch (error) {
      Logger.warnWithTag(
        'DESKTOP',
        'failed to update tray playback state',
        error,
      );
    }
  }

  Future<void> _installTrayIcon() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png',
      );
      _trayIconRegistered = true;
      if (Platform.isWindows) {
        await trayManager.setToolTip('Echoes');
      }
      await trayManager.setContextMenu(_buildTrayContextMenu());
      _trayAvailable =
          defaultTargetPlatform != TargetPlatform.linux ||
          _statusNotifierHostTracker.hasHost;
      Logger.infoWithTag(
        'DESKTOP',
        'tray initialized available=$_trayAvailable',
      );
    } catch (error) {
      _trayIconRegistered = false;
      _trayAvailable = false;
      Logger.warnWithTag('DESKTOP', 'tray unavailable', error);
    }
  }

  Future<void> _connectToStatusNotifierWatcher() async {
    DBusClient? client;
    try {
      _statusNotifierHostTracker.beginInitialLookup();
      client = DBusClient.session();
      _sessionBusClient = client;
      _watcherSubscription = client.nameOwnerChanged.listen(
        _onNameOwnerChanged,
        onError: (Object error) {
          _statusNotifierHostTracker.clear();
          _trayAvailable = false;
          if (_windowHidden && !_exitRequested) unawaited(showWindow());
          Logger.warnWithTag('DESKTOP', 'tray watcher monitor failed', error);
        },
      );
      for (final name in StatusNotifierHostTracker.watcherNames) {
        try {
          final owner = await client.getNameOwner(name);
          _statusNotifierHostTracker.applyInitialLookup(
            name,
            hasOwner: owner != null,
          );
        } catch (_) {
          // A missing watcher is a supported desktop configuration.
          _statusNotifierHostTracker.applyInitialLookup(name, hasOwner: false);
        }
      }
      _statusNotifierHostTracker.finishInitialLookup();
    } catch (error) {
      _statusNotifierHostTracker.clear();
      await _watcherSubscription?.cancel();
      _watcherSubscription = null;
      _sessionBusClient = null;
      await client?.close();
      Logger.warnWithTag('DESKTOP', 'cannot inspect tray host', error);
    }
  }

  void _onNameOwnerChanged(DBusNameOwnerChangedEvent event) {
    final wasAvailable = _statusNotifierHostTracker.hasHost;
    if (!_statusNotifierHostTracker.applyOwnerChange(
      event.name,
      hasOwner: event.newOwner != null,
    )) {
      return;
    }

    if (!_statusNotifierHostTracker.hasHost) {
      _trayAvailable = false;
      if (_windowHidden && !_exitRequested) {
        unawaited(showWindow());
      }
      Logger.warnWithTag(
        'DESKTOP',
        'tray host disappeared; restored window if it was hidden',
      );
      return;
    }

    if (!wasAvailable) {
      _trayAvailable = false;
      unawaited(_refreshTrayAfterHostAppeared());
    } else {
      _trayAvailable = _trayIconRegistered;
    }
  }

  Future<void> _refreshTrayAfterHostAppeared() async {
    if (!_trayIconRegistered || !_statusNotifierHostTracker.hasHost) return;
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png',
      );
      await trayManager.setContextMenu(_buildTrayContextMenu());
      _trayAvailable =
          _trayIconRegistered && _statusNotifierHostTracker.hasHost;
      Logger.infoWithTag(
        'DESKTOP',
        'tray registration refreshed after host appeared available=$_trayAvailable',
      );
    } catch (error) {
      _trayAvailable = false;
      Logger.warnWithTag(
        'DESKTOP',
        'failed to refresh tray after host appeared',
        error,
      );
    }
  }

  /// Dispatch menu actions only from [onTrayMenuItemClick]. tray_manager calls
  /// both a MenuItem.onClick callback and the TrayListener for the same item.
  Menu _buildTrayContextMenu() => Menu(
    items: <MenuItem>[
      MenuItem(key: 'show_window', label: '显示 Echo'),
      MenuItem.separator(),
      MenuItem(
        key: 'play_pause',
        label: _trayMenuState.playPauseLabel,
        disabled: !_trayMenuState.canTogglePlayback,
      ),
      MenuItem(
        key: 'previous',
        label: '上一首',
        disabled: !_trayMenuState.canGoPrevious,
      ),
      MenuItem(key: 'next', label: '下一首', disabled: !_trayMenuState.canGoNext),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出 Echo'),
    ],
  );

  Future<void> showWindow() async {
    try {
      await windowManager.show();
      _windowHidden = false;
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'failed to show main window', error);
      return;
    }
    try {
      await windowManager.focus();
    } catch (error) {
      // Wayland compositors may deny focus requests even after showing the
      // window. Keep the visible state accurate and leave focus to the user.
      Logger.warnWithTag('DESKTOP', 'window shown but focus was denied', error);
    }
  }

  Future<void> requestExit() async {
    if (_exitRequested || _exitCheckInProgress) return;
    _exitCheckInProgress = true;
    var approved = false;
    try {
      approved = await (_onBeforeQuit?.call() ?? Future<bool>.value(true));
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'exit confirmation failed', error);
    } finally {
      _exitCheckInProgress = false;
    }
    if (!approved) return;

    _exitRequested = true;
    await _runExitStep(
      'save window state',
      DesktopWindowStateService.instance.dispose,
    );
    final onQuit = _onQuit;
    if (onQuit != null) {
      await _runExitStep('stop playback', onQuit, timeout: _playerQuitTimeout);
    }

    final watcherSubscription = _watcherSubscription;
    _watcherSubscription = null;
    if (watcherSubscription != null) {
      await _runExitStep('stop tray host monitor', watcherSubscription.cancel);
    }
    final sessionBusClient = _sessionBusClient;
    _sessionBusClient = null;
    if (sessionBusClient != null) {
      await _runExitStep('close session bus', sessionBusClient.close);
    }
    await _runExitStep('destroy tray icon', trayManager.destroy);
    await _runExitStep('remove tray listener', () async {
      trayManager.removeListener(this);
    });
    await _runExitStep('remove window listener', () async {
      windowManager.removeListener(this);
    });
    await _runExitStep(
      'release close guard',
      () => windowManager.setPreventClose(false),
    );
    try {
      await windowManager.destroy().timeout(_windowDestroyTimeout);
    } catch (error) {
      _exitRequested = false;
      Logger.errorWithTag('DESKTOP', 'failed to destroy main window', error);
    }
  }

  Future<void> _runExitStep(
    String label,
    Future<void> Function() operation, {
    Duration timeout = _exitCleanupTimeout,
  }) async {
    try {
      await operation().timeout(timeout);
    } catch (error, stackTrace) {
      Logger.warnWithTag('DESKTOP', 'exit cleanup failed: $label', error);
      Logger.debugWithTag('DESKTOP', 'exit cleanup stack: $label', stackTrace);
    }
  }

  @override
  void onWindowClose() {
    if (_exitRequested || _closeActionPending) return;
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    _closeActionPending = true;
    try {
      if (await DesktopCloseSettings.shouldExitOnClose()) {
        await requestExit();
        return;
      }

      final shouldShowNotice =
          await DesktopCloseSettings.shouldShowFirstBackgroundCloseNotice();
      if (shouldShowNotice) {
        final shouldHide = await _onBeforeHide!(trayAvailable: _trayAvailable);
        if (!shouldHide) return;
      }

      final didHide = await _hideOrMinimize();
      if (didHide && shouldShowNotice) {
        try {
          await DesktopCloseSettings.markFirstBackgroundCloseNoticeSeen();
        } catch (error) {
          Logger.warnWithTag(
            'DESKTOP',
            'could not remember first background-close notice',
            error,
          );
        }
      }
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'window close action failed', error);
    } finally {
      _closeActionPending = false;
    }
  }

  Future<bool> _hideOrMinimize() async {
    try {
      if (_trayAvailable) {
        await windowManager.hide();
        _windowHidden = true;
        if (!_trayAvailable) {
          // The host can disappear after the availability check but before
          // hide completes. Recover a taskbar path instead of stranding the
          // process in an unobservable hidden state.
          Logger.warnWithTag(
            'DESKTOP',
            'tray host disappeared while hiding; falling back to minimize',
          );
          await windowManager.show();
          _windowHidden = false;
          await windowManager.minimize();
        }
      } else {
        // Keep a taskbar/dock recovery path when no StatusNotifier host exists.
        await windowManager.minimize();
        _windowHidden = false;
      }
      return true;
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'close-to-tray action failed', error);
      try {
        await windowManager.show();
        _windowHidden = false;
      } catch (_) {
        // Keep the close failure local to the desktop shell.
      }
      return false;
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (defaultTargetPlatform != TargetPlatform.linux) {
      unawaited(showWindow());
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(showWindow());
      case 'play_pause':
        if (_trayMenuState.canTogglePlayback) {
          unawaited(_onTogglePlayPause?.call());
        }
      case 'previous':
        if (_trayMenuState.canGoPrevious) {
          unawaited(_onPrevious?.call());
        }
      case 'next':
        if (_trayMenuState.canGoNext) {
          unawaited(_onNext?.call());
        }
      case 'quit':
        unawaited(requestExit());
    }
  }
}
