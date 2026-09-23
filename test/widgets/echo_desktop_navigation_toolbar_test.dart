import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/widgets/echo_app_shell/echo_desktop_navigation_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop app toolbar exposes browser-style navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EchoDesktopNavigationToolbar(
            canGoBack: true,
            canGoForward: false,
            onBack: () {},
            onForward: () {},
            onSearch: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('echo-desktop-navigation-toolbar')),
      findsOneWidget,
    );
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
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('echo-desktop-navigation-toolbar'),
            ),
          )
          .height,
      48,
    );
  });
}
