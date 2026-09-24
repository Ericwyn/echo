import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_identity.dart';
import '../utils/logger.dart';

/// Playback CPU lock with a native heartbeat watchdog, separate from screen wake.
class PlaybackWakeGuard {
  PlaybackWakeGuard({bool? enabled, MethodChannel? channel})
    : _enabled =
          enabled ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
      _channel =
          channel ??
          const MethodChannel('$echoApplicationId/playback_wake_guard');
  final bool _enabled;
  final MethodChannel _channel;
  Timer? _renewal;
  bool _active = false;
  bool _unavailable = false;
  int? _lastElapsed;
  int? _lastUptime;

  Future<void> setActive(bool active, {required String reason}) async {
    if (!_enabled || _unavailable) return;
    if (_active == active) {
      // A new song must reassert the native lock even if playback intent did
      // not change; the OS may have disabled it since the last heartbeat.
      if (active && reason == 'song_request') await _send(reason);
      return;
    }
    _active = active;
    if (active) {
      _lastElapsed = null;
      _lastUptime = null;
    }
    _renewal?.cancel();
    _renewal = active
        ? Timer.periodic(const Duration(seconds: 20), (_) {
            unawaited(_send('renew'));
          })
        : null;
    await _send(reason);
  }

  Future<void> _send(String reason) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setActive',
        {'active': _active, 'reason': reason},
      );
      if (result == null) return;
      final elapsed = result['elapsedMs'] as int;
      final uptime = result['uptimeMs'] as int;
      final gap = _lastElapsed == null ? 0 : elapsed - _lastElapsed!;
      final slept = _lastUptime == null ? 0 : gap - (uptime - _lastUptime!);
      _lastElapsed = elapsed;
      _lastUptime = uptime;
      Logger.infoWithTag(
        'PLAYBACK',
        'cpu_guard reason=$reason requested=$_active '
            'held=${result['held']} foreground=${result['serviceForeground']} '
            'interactive=${result['interactive']} idle=${result['deviceIdle']} '
            'batteryExempt=${result['batteryExempt']} powerSave=${result['powerSaveMode']} '
            'gapMs=$gap sleptMs=$slept',
      );
    } on MissingPluginException {
      _unavailable = true;
      _renewal?.cancel();
      Logger.warnWithTag('PLAYBACK', 'cpu_guard unavailable');
    } on PlatformException catch (error) {
      Logger.warnWithTag('PLAYBACK', 'cpu_guard failed code=${error.code}');
    }
  }

  Future<void> dispose() => setActive(false, reason: 'dispose');
}
