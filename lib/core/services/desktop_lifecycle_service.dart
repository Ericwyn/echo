import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart' show Size;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../design/layout/echo_desktop_metrics.dart';
import '../utils/logger.dart';
import 'desktop_window_state_service.dart';

const _statusNotifierWatchers = <String>[
  'org.kde.StatusNotifierWatcher',
  'org.freedesktop.StatusNotifierWatcher',
];

/// Owns desktop window/tray lifetime only. Playback remains in PlayerNotifier.
class DesktopLifecycleService with WindowListener, TrayListener {
  DesktopLifecycleService._();

  static final DesktopLifecycleService instance = DesktopLifecycleService._();

  Future<void> Function()? _onTogglePlayPause;
  Future<void> Function()? _onNext;
  Future<void> Function()? _onQuit;
  DBusClient? _sessionBusClient;
  StreamSubscription<DBusNameOwnerChangedEvent>? _watcherSubscription;
  String? _watcherName;
  bool _initialized = false;
  bool _exitRequested = false;
  bool _trayIconRegistered = false;
  bool _trayAvailable = false;
  bool _windowHidden = false;

  bool get trayAvailable => _trayAvailable;

  Future<void> initialize({
    required Future<void> Function() onTogglePlayPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onQuit,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _onTogglePlayPause = onTogglePlayPause;
    _onNext = onNext;
    _onQuit = onQuit;

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

  Future<void> _installTrayIcon() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png',
      );
      _trayIconRegistered = true;
      if (Platform.isWindows) {
        await trayManager.setToolTip('Echoes');
      }
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            MenuItem(
              key: 'show_window',
              label: '显示 Echo',
              onClick: (_) => unawaited(showWindow()),
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'play_pause',
              label: '播放 / 暂停',
              onClick: (_) => unawaited(_onTogglePlayPause?.call()),
            ),
            MenuItem(
              key: 'next',
              label: '下一首',
              onClick: (_) => unawaited(_onNext?.call()),
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'quit',
              label: '退出 Echo',
              onClick: (_) => unawaited(requestExit()),
            ),
          ],
        ),
      );
      if (defaultTargetPlatform != TargetPlatform.linux ||
          _watcherName != null) {
        _trayAvailable = true;
      }
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
      client = DBusClient.session();
      for (final name in _statusNotifierWatchers) {
        try {
          final owner = await client.getNameOwner(name);
          if (owner != null) {
            _watcherName = name;
            break;
          }
        } catch (_) {
          // A missing watcher is a supported desktop configuration.
        }
      }
      _sessionBusClient = client;
      _watcherSubscription = client.nameOwnerChanged.listen(
        _onNameOwnerChanged,
        onError: (Object error) {
          Logger.warnWithTag('DESKTOP', 'tray watcher monitor failed', error);
        },
      );
    } catch (error) {
      await client?.close();
      Logger.warnWithTag('DESKTOP', 'cannot inspect tray host', error);
    }
  }

  void _onNameOwnerChanged(DBusNameOwnerChangedEvent event) {
    if (!_statusNotifierWatchers.contains(event.name)) return;
    if (event.newOwner == null) {
      _watcherName = null;
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

    _watcherName = event.name;
    _trayAvailable = _trayIconRegistered;
    if (_windowHidden && !_exitRequested) {
      // The icon is available again, but leave the user's hidden-window choice
      // intact. The tray menu is now the recovery route.
    }
  }

  Future<void> showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      _windowHidden = false;
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'failed to show main window', error);
    }
  }

  Future<void> requestExit() async {
    if (_exitRequested) return;
    _exitRequested = true;
    try {
      await DesktopWindowStateService.instance.dispose();
      await _onQuit?.call();
      await _watcherSubscription?.cancel();
      _watcherSubscription = null;
      await _sessionBusClient?.close();
      _sessionBusClient = null;
      await trayManager.destroy();
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (error) {
      _exitRequested = false;
      Logger.errorWithTag('DESKTOP', 'failed to exit cleanly', error);
    }
  }

  @override
  void onWindowClose() {
    if (_exitRequested) return;
    unawaited(_hideOrMinimize());
  }

  Future<void> _hideOrMinimize() async {
    try {
      if (_trayAvailable) {
        await windowManager.hide();
        _windowHidden = true;
      } else {
        // Keep a taskbar/dock recovery path when no StatusNotifier host exists.
        await windowManager.minimize();
        _windowHidden = false;
      }
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'close-to-tray action failed', error);
      try {
        await windowManager.show();
      } catch (_) {
        // Keep the close failure local to the desktop shell.
      }
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
        unawaited(_onTogglePlayPause?.call());
      case 'next':
        unawaited(_onNext?.call());
      case 'quit':
        unawaited(requestExit());
    }
  }
}
