import 'package:echoes/core/services/desktop_close_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'background close notice is shown until the first hide succeeds',
    () async {
      expect(
        await DesktopCloseSettings.shouldShowFirstBackgroundCloseNotice(),
        isTrue,
      );

      await DesktopCloseSettings.markFirstBackgroundCloseNoticeSeen();

      expect(
        await DesktopCloseSettings.shouldShowFirstBackgroundCloseNotice(),
        isFalse,
      );
    },
  );

  test(
    'window close still defaults to keeping playback in the background',
    () async {
      expect(await DesktopCloseSettings.shouldExitOnClose(), isFalse);
    },
  );
}
