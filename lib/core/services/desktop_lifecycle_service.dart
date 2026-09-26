import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart' show Size;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/player/playback_contract.dart';
import '../constants/app_identity.dart';
import '../design/layout/echo_desktop_metrics.dart';
import '../utils/logger.dart';
import 'desktop_close_settings.dart';
import 'desktop_tray_menu_state.dart';
import 'desktop_window_state_service.dart';
import 'status_notifier_host_tracker.dart';

const _exitCleanupTimeout = Duration(seconds: 4);
const _playerQuitTimeout = Duration(seconds: 15);
const _windowDestroyTimeout = Duration(seconds: 8);
const _watcherStableResetDelay = Duration(seconds: 30);
const _watcherReconnectMaximumAttempt = 6;

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
  Timer? _watcherReconnectTimer;
  Timer? _watcherStableTimer;
  final StatusNotifierHostTracker _statusNotifierHostTracker =
      StatusNotifierHostTracker();
  bool _initialized = false;
  bool _watcherConnectInProgress = false;
  bool _exitRequested = false;
  bool _trayIconRegistered = false;
  bool _trayAvailable = false;
  bool _windowHidden = false;
  bool _closeActionPending = false;
  bool _exitCheckInProgress = false;
  int _watcherGeneration = 0;
  int _watcherReconnectAttempt = 0;
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
      await windowManager.setTitle(echoDisplayName());
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
        await trayManager.setToolTip(echoDisplayName());
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

  Future<void> _connectToStatusNotifierWatcher({
    bool refreshTrayOnSuccess = false,
  }) async {
    if (_exitRequested || _watcherConnectInProgress) return;
    _watcherConnectInProgress = true;
    final generation = ++_watcherGeneration;
    DBusClient? client;
    try {
      _statusNotifierHostTracker.beginInitialLookup();
      client = DBusClient.session();
      _sessionBusClient = client;
      _watcherSubscription = client.nameOwnerChanged.listen(
        (event) {
          if (_isCurrentWatcher(generation)) _onNameOwnerChanged(event);
        },
        onError: (Object error) {
          unawaited(_handleWatcherConnectionFailure(generation, error));
        },
        onDone: () => unawaited(
          _handleWatcherConnectionFailure(
            generation,
            StateError('StatusNotifierWatcher monitor closed'),
          ),
        ),
      );
      for (final name in StatusNotifierHostTracker.watcherNames) {
        try {
          final owner = await client.getNameOwner(name);
          if (!_isCurrentWatcher(generation)) return;
          _statusNotifierHostTracker.applyInitialLookup(
            name,
            hasOwner: owner != null,
          );
        } catch (_) {
          // A missing watcher is a supported desktop configuration.
          if (!_isCurrentWatcher(generation)) return;
          _statusNotifierHostTracker.applyInitialLookup(name, hasOwner: false);
        }
      }
      if (!_isCurrentWatcher(generation)) return;
      _statusNotifierHostTracker.finishInitialLookup();
      _watcherStableTimer?.cancel();
      _watcherStableTimer = Timer(_watcherStableResetDelay, () {
        if (_isCurrentWatcher(generation)) _watcherReconnectAttempt = 0;
      });
      _watcherReconnectTimer?.cancel();
      _watcherReconnectTimer = null;
      _trayAvailable =
          _trayIconRegistered && _statusNotifierHostTracker.hasHost;
      if (refreshTrayOnSuccess && _statusNotifierHostTracker.hasHost) {
        await _restoreTrayRegistrationAfterHostAppeared();
      }
    } catch (error) {
      if (_isCurrentWatcher(generation)) {
        await _handleWatcherConnectionFailure(
          generation,
          error,
          failedClient: client,
        );
      }
    } finally {
      _watcherConnectInProgress = false;
    }
  }

  bool _isCurrentWatcher(int generation) =>
      generation == _watcherGeneration && !_exitRequested;

  Future<void> _handleWatcherConnectionFailure(
    int generation,
    Object error, {
    DBusClient? failedClient,
  }) async {
    if (!_isCurrentWatcher(generation)) return;
    ++_watcherGeneration;
    _watcherStableTimer?.cancel();
    _watcherStableTimer = null;
    _statusNotifierHostTracker.clear();
    _trayAvailable = false;

    final subscription = _watcherSubscription;
    _watcherSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel().timeout(_exitCleanupTimeout);
      } catch (cleanupError) {
        Logger.warnWithTag(
          'DESKTOP',
          'could not stop failed tray host monitor',
          cleanupError,
        );
      }
    }
    final activeClient = _sessionBusClient;
    final clientToClose = failedClient ?? activeClient;
    if (failedClient == null || identical(activeClient, failedClient)) {
      _sessionBusClient = null;
    }
    try {
      await clientToClose?.close().timeout(_exitCleanupTimeout);
    } catch (cleanupError) {
      Logger.warnWithTag(
        'DESKTOP',
        'could not close failed session bus connection',
        cleanupError,
      );
    }

    if (_windowHidden && !_exitRequested) unawaited(showWindow());
    Logger.warnWithTag('DESKTOP', 'tray watcher monitor failed', error);
    _scheduleWatcherReconnect();
  }

  void _scheduleWatcherReconnect() {
    if (_exitRequested || _watcherReconnectTimer != null) return;
    if (_watcherReconnectAttempt < _watcherReconnectMaximumAttempt) {
      _watcherReconnectAttempt++;
    }
    final delay = statusNotifierReconnectDelay(_watcherReconnectAttempt);
    Logger.infoWithTag(
      'DESKTOP',
      'retrying tray host monitor in ${delay.inSeconds}s',
    );
    _watcherReconnectTimer = Timer(delay, () {
      _watcherReconnectTimer = null;
      _attemptWatcherReconnect();
    });
  }

  void _attemptWatcherReconnect() {
    if (_exitRequested) return;
    if (_watcherConnectInProgress) {
      _watcherReconnectTimer = Timer(const Duration(seconds: 1), () {
        _watcherReconnectTimer = null;
        _attemptWatcherReconnect();
      });
      return;
    }
    unawaited(_connectToStatusNotifierWatcher(refreshTrayOnSuccess: true));
  }

  Future<void> _restoreTrayRegistrationAfterHostAppeared() async {
    if (_trayIconRegistered) {
      await _refreshTrayAfterHostAppeared();
    } else {
      await _installTrayIcon();
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
      unawaited(_restoreTrayRegistrationAfterHostAppeared());
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
      MenuItem(key: 'show_window', label: '显示 ${echoDisplayName()}'),
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
      MenuItem(key: 'quit', label: '退出 ${echoDisplayName()}'),
    ],
  );

  Future<void> showWindow() async {
    await showWindowWithBestEffortFocus(
      show: windowManager.show,
      focus: windowManager.focus,
      onShown: () => _windowHidden = false,
      onShowFailure: (error) =>
          Logger.warnWithTag('DESKTOP', 'failed to show main window', error),
      onFocusFailure: (error) => Logger.warnWithTag(
        'DESKTOP',
        'window shown but focus was denied',
        error,
      ),
    );
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
    _watcherReconnectTimer?.cancel();
    _watcherReconnectTimer = null;
    _watcherStableTimer?.cancel();
    _watcherStableTimer = null;
    ++_watcherGeneration;

    // Remove the tray affordance before the slower persistence/player
    // shutdown work. This gives immediate feedback for a tray-initiated exit
    // and prevents the user from clicking a now-inert menu while cleanup runs.
    await _runExitStep('destroy tray icon', trayManager.destroy);
    await _runExitStep('remove tray listener', () async {
      trayManager.removeListener(this);
    });

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
      Logger.errorWithTag('DESKTOP', 'failed to destroy main window', error);
      await _restoreAfterDestroyFailure();
    }
  }

  Future<void> _restoreAfterDestroyFailure() async {
    _exitRequested = false;
    _windowHidden = false;
    _trayAvailable = false;
    _trayIconRegistered = false;

    await _runRecoveryStep(
      'restore close guard',
      () => windowManager.setPreventClose(true),
    );
    await _runRecoveryStep('restore window listener', () async {
      windowManager.removeListener(this);
      windowManager.addListener(this);
    });
    await _runRecoveryStep('restore tray listener', () async {
      trayManager.removeListener(this);
      trayManager.addListener(this);
    });
    await _runRecoveryStep(
      'restore window state persistence',
      DesktopWindowStateService.instance.initialize,
    );

    if (defaultTargetPlatform == TargetPlatform.linux) {
      if (_watcherConnectInProgress) {
        // Exit may race startup's initial owner lookup. Retry after that
        // invalidated request settles instead of silently losing the monitor.
        _scheduleWatcherReconnect();
      } else {
        await _connectToStatusNotifierWatcher(refreshTrayOnSuccess: true);
      }
    }
    if (!_trayIconRegistered) {
      await _runRecoveryStep('restore tray icon', _installTrayIcon);
    }

    await showWindowWithMinimizeFallback(
      show: windowManager.show,
      focus: windowManager.focus,
      minimize: windowManager.minimize,
      onShown: () => _windowHidden = false,
      onShowFailure: (error) => Logger.warnWithTag(
        'DESKTOP',
        'failed to restore main window after exit failure',
        error,
      ),
      onFocusFailure: (error) => Logger.warnWithTag(
        'DESKTOP',
        'restored window but could not focus it after exit failure',
        error,
      ),
      onMinimizeFailure: (error) => Logger.warnWithTag(
        'DESKTOP',
        'could not minimize window after failed restore',
        error,
      ),
    );
  }

  Future<void> _runRecoveryStep(
    String label,
    Future<void> Function() operation,
  ) async {
    try {
      await operation().timeout(_exitCleanupTimeout);
    } catch (error, stackTrace) {
      Logger.warnWithTag('DESKTOP', 'exit recovery failed: $label', error);
      Logger.debugWithTag('DESKTOP', 'exit recovery stack: $label', stackTrace);
    }
  }

  Future<void> _runExitStep(
    String label,
    Future<void> Function() operation, {
    Duration timeout = _exitCleanupTimeout,
  }) async {
    final watch = Stopwatch()..start();
    try {
      await operation().timeout(timeout);
    } catch (error, stackTrace) {
      Logger.warnWithTag('DESKTOP', 'exit cleanup failed: $label', error);
      Logger.debugWithTag('DESKTOP', 'exit cleanup stack: $label', stackTrace);
    } finally {
      if (watch.elapsedMilliseconds > 200) {
        Logger.infoWithTag(
          'DESKTOP',
          'exit_cleanup_slow step=$label elapsedMs=${watch.elapsedMilliseconds}',
        );
      }
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
      final trayAvailableAtStart = _trayAvailable;
      final result = await closeWindowWithTrayRecovery(
        trayAvailableAtStart: trayAvailableAtStart,
        trayAvailableNow: () => _trayAvailable,
        hideWindow: windowManager.hide,
        showWindow: windowManager.show,
        minimizeWindow: windowManager.minimize,
        onHiddenChanged: (hidden) => _windowHidden = hidden,
      );
      if (trayAvailableAtStart &&
          result == DesktopWindowCloseResult.minimized) {
        Logger.warnWithTag(
          'DESKTOP',
          'tray host disappeared while hiding; fell back to minimize',
        );
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
    unawaited(showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_showTrayContextMenu());
  }

  Future<void> _showTrayContextMenu() async {
    try {
      // Windows requires the owner window to be foregrounded while tracking a
      // native popup menu, including when the main window itself is hidden.
      // ignore: deprecated_member_use
      await trayManager.popUpContextMenu(bringAppToFront: true);
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'failed to show tray context menu', error);
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

enum DesktopWindowCloseResult { hidden, minimized }

@visibleForTesting
Duration statusNotifierReconnectDelay(int attempt) {
  if (attempt <= 1) return const Duration(seconds: 1);
  if (attempt == 2) return const Duration(seconds: 2);
  if (attempt == 3) return const Duration(seconds: 4);
  if (attempt == 4) return const Duration(seconds: 8);
  if (attempt == 5) return const Duration(seconds: 16);
  return const Duration(seconds: 30);
}

@visibleForTesting
Future<bool> showWindowWithBestEffortFocus({
  required Future<void> Function() show,
  required Future<void> Function() focus,
  required void Function() onShown,
  required void Function(Object error) onShowFailure,
  required void Function(Object error) onFocusFailure,
}) async {
  try {
    await show();
    onShown();
  } catch (error) {
    onShowFailure(error);
    return false;
  }

  try {
    await focus();
  } catch (error) {
    // Wayland compositors may deny focus requests even after showing the
    // window. Keep the visible state accurate and leave focus to the user.
    onFocusFailure(error);
  }
  return true;
}

@visibleForTesting
Future<bool> showWindowWithMinimizeFallback({
  required Future<void> Function() show,
  required Future<void> Function() focus,
  required Future<void> Function() minimize,
  required void Function() onShown,
  required void Function(Object error) onShowFailure,
  required void Function(Object error) onFocusFailure,
  required void Function(Object error) onMinimizeFailure,
}) async {
  final shown = await showWindowWithBestEffortFocus(
    show: show,
    focus: focus,
    onShown: onShown,
    onShowFailure: onShowFailure,
    onFocusFailure: onFocusFailure,
  );
  if (shown) return true;

  try {
    await minimize();
  } catch (error) {
    onMinimizeFailure(error);
  }
  return false;
}

@visibleForTesting
Future<DesktopWindowCloseResult> closeWindowWithTrayRecovery({
  required bool trayAvailableAtStart,
  required bool Function() trayAvailableNow,
  required Future<void> Function() hideWindow,
  required Future<void> Function() showWindow,
  required Future<void> Function() minimizeWindow,
  required void Function(bool hidden) onHiddenChanged,
}) async {
  if (!trayAvailableAtStart) {
    // Keep a taskbar/dock recovery path when no StatusNotifier host exists.
    await minimizeWindow();
    onHiddenChanged(false);
    return DesktopWindowCloseResult.minimized;
  }

  await hideWindow();
  onHiddenChanged(true);
  if (trayAvailableNow()) return DesktopWindowCloseResult.hidden;

  // The host can disappear after the availability check but before hide
  // completes. Recover a taskbar path instead of stranding the process.
  await showWindow();
  onHiddenChanged(false);
  await minimizeWindow();
  return DesktopWindowCloseResult.minimized;
}
