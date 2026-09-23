import 'package:echoes/core/services/desktop_window_state_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var isFullScreen = false;
  var width = 1280.0;
  var height = 800.0;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'desktop.window.width': 1280.0,
      'desktop.window.height': 800.0,
      'desktop.window.maximized': false,
    });
    isFullScreen = false;
    width = 1280;
    height = 800;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isMaximized':
          return false;
        case 'isFullScreen':
          return isFullScreen;
        case 'isMinimized':
          return false;
        case 'getBounds':
          return <String, Object>{
            'x': 0.0,
            'y': 0.0,
            'width': width,
            'height': height,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await DesktopWindowStateService.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'fullscreen dimensions do not replace the normal restored size',
    () async {
      final service = DesktopWindowStateService.instance;
      await service.initialize();
      final preferences = await SharedPreferences.getInstance();

      isFullScreen = true;
      width = 1920;
      height = 1080;
      service.onWindowEnterFullScreen();
      service.onWindowResize();
      await service.flush();

      expect(preferences.getDouble('desktop.window.width'), 1280);
      expect(preferences.getDouble('desktop.window.height'), 800);

      isFullScreen = false;
      width = 1366;
      height = 768;
      service.onWindowLeaveFullScreen();
      await service.flush();

      expect(preferences.getDouble('desktop.window.width'), 1366);
      expect(preferences.getDouble('desktop.window.height'), 768);
    },
  );
}
