import 'package:shared_preferences/shared_preferences.dart';

/// Stores desktop window-close behavior and its one-time recovery notice state.
class DesktopCloseSettings {
  DesktopCloseSettings._();

  static const _exitOnCloseKey = 'desktop.exitOnClose';
  static const _backgroundCloseNoticeSeenKey =
      'desktop.backgroundCloseNoticeSeen';

  /// Defaults to keeping the current tray/background behavior.
  static Future<bool> shouldExitOnClose() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_exitOnCloseKey) ?? false;
  }

  static Future<void> setExitOnClose(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_exitOnCloseKey, value);
  }

  static Future<bool> shouldShowFirstBackgroundCloseNotice() async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_backgroundCloseNoticeSeenKey) ?? false);
  }

  static Future<void> markFirstBackgroundCloseNoticeSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_backgroundCloseNoticeSeenKey, true);
  }
}
