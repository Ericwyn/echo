import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../design/layout/echo_desktop_metrics.dart';
import '../utils/logger.dart';

const _windowWidthKey = 'desktop.window.width';
const _windowHeightKey = 'desktop.window.height';
const _windowMaximizedKey = 'desktop.window.maximized';
const _windowStateWriteDelay = Duration(milliseconds: 500);
const _maximumRestoredWindowDimension = 7680.0;

/// Persists restorable window state without taking ownership of playback.
///
/// Position is intentionally not saved: Wayland compositors do not guarantee
/// that absolute window positioning works, and a saved position can point to a
/// monitor that is no longer connected.
class DesktopWindowStateService with WindowListener {
  DesktopWindowStateService._();

  static final DesktopWindowStateService instance =
      DesktopWindowStateService._();

  SharedPreferences? _preferences;
  Timer? _writeTimer;
  bool _initialized = false;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  /// Applies the last size before Flutter's first frame makes the window
  /// visible, avoiding a resize jump after startup.
  static Future<void> restoreBeforeFirstFrame() async {
    if (defaultTargetPlatform != TargetPlatform.linux) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      final width = _restorableDimension(
        preferences.getDouble(_windowWidthKey),
        echoDesktopMinimumWindowWidth,
      );
      final height = _restorableDimension(
        preferences.getDouble(_windowHeightKey),
        echoDesktopMinimumWindowHeight,
      );

      if (width != null && height != null) {
        await windowManager.setSize(Size(width, height));
      }
      if (preferences.getBool(_windowMaximizedKey) ?? false) {
        await windowManager.maximize();
      }
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'cannot restore window state', error);
    }
  }

  Future<void> initialize() async {
    if (_initialized || defaultTargetPlatform != TargetPlatform.linux) return;
    _initialized = true;

    try {
      _preferences = await SharedPreferences.getInstance();
      _isMaximized = await windowManager.isMaximized();
      _isFullScreen = await windowManager.isFullScreen();
      windowManager.addListener(this);
    } catch (error) {
      _initialized = false;
      Logger.warnWithTag(
        'DESKTOP',
        'window state persistence unavailable',
        error,
      );
    }
  }

  @override
  void onWindowResize() {
    if (!_isMaximized && !_isFullScreen) _scheduleWrite();
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    _scheduleWrite();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    _scheduleWrite();
  }

  @override
  void onWindowRestore() {
    _isMaximized = false;
    _scheduleWrite();
  }

  @override
  void onWindowEnterFullScreen() {
    _isFullScreen = true;
    _writeTimer?.cancel();
    _writeTimer = null;
  }

  @override
  void onWindowLeaveFullScreen() {
    _isFullScreen = false;
    _scheduleWrite();
  }

  @override
  void onWindowClose() {
    unawaited(flush());
  }

  void _scheduleWrite() {
    _writeTimer?.cancel();
    _writeTimer = Timer(_windowStateWriteDelay, () {
      unawaited(flush());
    });
  }

  /// Writes the latest normal size and maximize state before an explicit exit.
  Future<void> flush() async {
    final preferences = _preferences;
    if (preferences == null) return;

    _writeTimer?.cancel();
    _writeTimer = null;
    try {
      if (_isFullScreen || await windowManager.isFullScreen()) return;
      final maximized = await windowManager.isMaximized();
      _isMaximized = maximized;
      await preferences.setBool(_windowMaximizedKey, maximized);
      if (maximized || await windowManager.isMinimized()) return;

      final size = await windowManager.getSize();
      if (!_isValidDimension(size.width) || !_isValidDimension(size.height)) {
        return;
      }
      await preferences.setDouble(_windowWidthKey, size.width);
      await preferences.setDouble(_windowHeightKey, size.height);
    } catch (error) {
      Logger.warnWithTag('DESKTOP', 'cannot save window state', error);
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await flush();
    _writeTimer?.cancel();
    _writeTimer = null;
    windowManager.removeListener(this);
    _preferences = null;
    _initialized = false;
  }
}

double? _restorableDimension(double? value, double minimum) {
  if (value == null || !_isValidDimension(value)) return null;
  return value.clamp(minimum, _maximumRestoredWindowDimension).toDouble();
}

bool _isValidDimension(double value) =>
    value.isFinite && value >= 1 && value <= _maximumRestoredWindowDimension;
