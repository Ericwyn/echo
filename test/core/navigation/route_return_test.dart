import 'package:echoes/core/navigation/route_return.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('returns through the nearest nested navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey<String>('open-editor'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (editorContext) => Scaffold(
                      body: TextButton(
                        key: const ValueKey<String>('save-editor'),
                        onPressed: () => popCurrentRouteOrGoHome(editorContext),
                        child: const Text('Save'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('save-editor')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('deleted-route return keeps mobile nested Navigator behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey<String>('open-mobile-editor'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (editorContext) => Scaffold(
                      body: TextButton(
                        key: const ValueKey<String>('delete-mobile-editor'),
                        onPressed: () =>
                            popCurrentRouteAndDiscardForwardOrGoHome(
                              editorContext,
                            ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mobile settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-mobile-editor')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('delete-mobile-editor')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobile settings'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to Home when there is no previous route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/edit',
      routes: <RouteBase>[
        GoRoute(
          path: '/edit',
          builder: (context, state) => Scaffold(
            body: TextButton(
              key: const ValueKey<String>('finish-direct-edit'),
              onPressed: () => popCurrentRouteOrGoHome(context),
              child: const Text('Finish'),
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const ValueKey<String>('finish-direct-edit')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
