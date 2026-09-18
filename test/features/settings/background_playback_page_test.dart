import 'package:echoes/core/services/background_playback_service.dart';
import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/features/settings/pages/background_playback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('battery status refreshes after returning from system settings', (
    tester,
  ) async {
    const channel = MethodChannel('echo-test-background-page');
    var exempt = false;
    var reads = 0;
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method != 'getStatus') return true;
      reads++;
      return {
        'batteryExempt': exempt,
        'powerSaveMode': false,
        'manufacturer': 'samsung',
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const BackgroundPlaybackPage(
          service: BackgroundPlaybackService(channel: channel),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('未排除系统电池优化'), findsOneWidget);
    expect(find.textContaining('休眠、深度休眠名单无法自动检测'), findsOneWidget);
    await tester.tap(find.text('系统电池优化'));
    await tester.pumpAndSettle();
    expect(calls, contains('openBatterySettings'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    exempt = true;
    final previousReads = reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads, greaterThan(previousReads));
    expect(find.textContaining('已排除系统电池优化'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
