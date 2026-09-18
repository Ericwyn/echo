import 'package:echoes/core/services/background_playback_service.dart';
import 'package:echoes/core/services/background_playback_advisor.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('echo-test-background');
  const service = BackgroundPlaybackService(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'reports system exemption separately from power saving and manufacturer',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getStatus');
        return {
          'batteryExempt': true,
          'powerSaveMode': true,
          'manufacturer': 'Samsung',
        };
      });
      final status = await service.readStatus();
      expect(status.batteryExempt, isTrue);
      expect(status.powerSaveMode, isTrue);
      expect(status.isSamsung, isTrue);
    },
  );

  test(
    'failed checks stay unknown and unavailable settings return false',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      final status = await service.readStatus();
      expect(status.batteryExempt, isNull);
      expect(status.powerSaveMode, isNull);
      expect(await service.openSettings(BackgroundSettingsTarget.app), isFalse);
    },
  );

  test('settings actions only run when explicitly requested', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'getStatus' ? <String, dynamic>{} : true;
    });
    await service.readStatus();
    expect(calls, ['getStatus']);
    expect(
      await service.openSettings(BackgroundSettingsTarget.battery),
      isTrue,
    );
    expect(
      await service.openSettings(BackgroundSettingsTarget.samsung),
      isTrue,
    );
    expect(calls, ['getStatus', 'openBatterySettings', 'openSamsungSettings']);
  });

  test('delay hint waits for resume and appears only once per session', () {
    var count = 0;
    final advisor = BackgroundPlaybackAdvisor(notify: () => count++);
    advisor.recordGap(gap: const Duration(seconds: 10), wasBackground: false);
    advisor.onLifecycle(AppLifecycleState.paused);
    advisor.recordGap(gap: const Duration(seconds: 2), wasBackground: true);
    advisor.onLifecycle(AppLifecycleState.resumed);
    expect(count, 0);
    advisor.onLifecycle(AppLifecycleState.paused);
    advisor.recordGap(gap: const Duration(seconds: 24), wasBackground: true);
    expect(count, 0);
    advisor.onLifecycle(AppLifecycleState.resumed);
    expect(count, 1);
    advisor.recordGap(gap: const Duration(seconds: 24), wasBackground: true);
    advisor.onLifecycle(AppLifecycleState.resumed);
    expect(count, 1);
  });
}
