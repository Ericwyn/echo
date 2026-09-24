import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/core/design/echo_design.dart';
import 'package:echoes/widgets/echo_app_shell/echo_desktop_window_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(find.text('Echo'), findsOneWidget);
      expect(find.text('Echoes'), findsNothing);
      expect(tester.getSize(titleBar).height, 53);
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

  testWidgets('title bar buttons receive clicks with native GTK frame', (
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
        builder: (context, child) =>
            EchoDesktopWindowChrome(child: child ?? const SizedBox.shrink()),
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

  testWidgets('one title bar contains brand, navigation, search and controls', (
    tester,
  ) async {
    late EchoDesktopWindowChromeController controller;
    var backCount = 0;
    var searchCount = 0;
    final owner = Object();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EchoDesktopWindowChrome(
          child: Builder(
            builder: (context) {
              controller = EchoDesktopWindowChromeScope.maybeOf(context)!;
              return const Scaffold(body: Text('Desktop route'));
            },
          ),
        ),
      ),
    );
    controller.showNavigation(
      owner,
      EchoDesktopChromeNavigation(
        canGoBack: true,
        canGoForward: false,
        onBack: () => backCount++,
        onForward: () {},
        onSearch: () => searchCount++,
      ),
    );
    await tester.pump();

    expect(find.text('Echo'), findsOneWidget);
    expect(find.text('Echoes'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('echo-desktop-back')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('echo-desktop-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('echo-desktop-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('echo-window-close')),
      findsOneWidget,
    );
    final backButton = find.byKey(const ValueKey<String>('echo-desktop-back'));
    final forwardButton = find.byKey(
      const ValueKey<String>('echo-desktop-forward'),
    );
    final searchButton = find.byKey(
      const ValueKey<String>('echo-desktop-search'),
    );
    expect(
      tester.widget<EchoIconButton>(backButton).backgroundColor,
      Colors.transparent,
    );
    expect(
      tester.widget<EchoIconButton>(forwardButton).backgroundColor,
      Colors.transparent,
    );
    expect(
      tester.getTopLeft(searchButton).dx,
      greaterThan(tester.getTopRight(forwardButton).dx),
    );
    expect(
      tester.getTopRight(searchButton).dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('echo-window-minimize')),
            )
            .dx,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('echo-desktop-back')));
    await tester.tap(find.byKey(const ValueKey<String>('echo-desktop-search')));
    expect(backCount, 1);
    expect(searchCount, 1);

    controller.clearNavigation(owner);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('echo-desktop-back')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('echo-desktop-search')),
      findsNothing,
    );
  });
}
