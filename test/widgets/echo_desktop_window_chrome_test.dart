import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/widgets/echo_app_shell/echo_desktop_window_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart' show VirtualWindowFrame;

void main() {
  testWidgets(
    'custom title bar wraps every route and provides window actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: EchoDesktopWindowChrome(
            child: const Scaffold(body: Center(child: Text('Login route'))),
          ),
        ),
      );
      await tester.pump();

      final titleBar = find.byKey(
        const ValueKey<String>('echo-desktop-window-chrome'),
      );
      expect(titleBar, findsOneWidget);
      expect(find.text('Login route'), findsOneWidget);
      expect(find.bySemanticsLabel('最小化窗口'), findsOneWidget);
      expect(find.bySemanticsLabel('最大化窗口'), findsOneWidget);
      expect(find.bySemanticsLabel('关闭窗口'), findsOneWidget);
      expect(tester.getSize(titleBar).height, 42);
    },
  );

  testWidgets('window controls build in MaterialApp.builder above Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('Route content'))),
        builder: (context, child) =>
            EchoDesktopWindowChrome(child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Route content'), findsOneWidget);
    expect(find.bySemanticsLabel('关闭窗口'), findsOneWidget);
  });

  testWidgets('title bar buttons receive clicks above resize hit zones', (
    tester,
  ) async {
    const channel = MethodChannel('window_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isMaximized') return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('Route content'))),
        builder: (context, child) => VirtualWindowFrame(
          child: EchoDesktopWindowChrome(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('echo-window-minimize')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('echo-window-maximize')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('echo-window-close')));
    await tester.pumpAndSettle();

    expect(calls, containsAll(<String>['minimize', 'maximize', 'close']));
    expect(tester.takeException(), isNull);
  });
}
