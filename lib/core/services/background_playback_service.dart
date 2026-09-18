import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

class BackgroundPlaybackStatus {
  const BackgroundPlaybackStatus({
    this.batteryExempt,
    this.powerSaveMode,
    this.manufacturer,
  });

  // Null means unavailable, never interpret a failed check as unrestricted.
  final bool? batteryExempt;
  final bool? powerSaveMode;
  final String? manufacturer;
  bool get isSamsung => manufacturer?.toLowerCase() == 'samsung';
}

enum BackgroundSettingsTarget { battery, app, power, samsung }

class BackgroundPlaybackService {
  const BackgroundPlaybackService({
    this.channel = const MethodChannel('com.az1n.echoes/playback_wake_guard'),
  });

  final MethodChannel channel;

  Future<BackgroundPlaybackStatus> readStatus() async {
    try {
      final data = await channel
          .invokeMapMethod<String, dynamic>('getStatus')
          .timeout(const Duration(seconds: 5));
      return BackgroundPlaybackStatus(
        batteryExempt: data?['batteryExempt'] as bool?,
        powerSaveMode: data?['powerSaveMode'] as bool?,
        manufacturer: data?['manufacturer'] as String?,
      );
    } on MissingPluginException {
      return const BackgroundPlaybackStatus();
    } on PlatformException catch (error) {
      Logger.warnWithTag('PLAYBACK', 'background_settings code=${error.code}');
      return const BackgroundPlaybackStatus();
    } on TimeoutException {
      return const BackgroundPlaybackStatus();
    }
  }

  Future<bool> openSettings(BackgroundSettingsTarget target) async {
    final method = switch (target) {
      BackgroundSettingsTarget.battery => 'openBatterySettings',
      BackgroundSettingsTarget.app => 'openAppSettings',
      BackgroundSettingsTarget.power => 'openPowerSettings',
      BackgroundSettingsTarget.samsung => 'openSamsungSettings',
    };
    try {
      return await channel
              .invokeMethod<bool>(method)
              .timeout(const Duration(seconds: 5)) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
