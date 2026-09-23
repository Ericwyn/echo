import 'package:shared_preferences/shared_preferences.dart';

/// Stores the Linux desktop behavior for the main window close button.
class DesktopCloseSettings {
  DesktopCloseSettings._();

  static const _exitOnCloseKey = 'desktop.exitOnClose';

  /// Defaults to keeping the current tray/background behavior.
  static Future<bool> shouldExitOnClose() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_exitOnCloseKey) ?? false;
  }

  static Future<void> setExitOnClose(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_exitOnCloseKey, value);
  }
}
