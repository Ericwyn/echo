import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/core/design/echo_design.dart';
import 'package:echoes/providers/navigation_provider.dart';
import 'package:echoes/widgets/main_scaffold.dart';
import 'package:echoes/widgets/echo_app_shell/echo_network_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('MainScaffold back decision', () {
    test('keeps the established five-level priority', () {
      expect(
        resolveEchoBackAction(
          drawerOpen: true,
          rootCanPop: true,
          branchCanPop: true,
          currentBranchIndex: libraryBranchIndex,
        ),
        EchoBackAction.closeDrawer,
      );
      expect(
        resolveEchoBackAction(
          drawerOpen: false,
          rootCanPop: true,
          branchCanPop: true,
          currentBranchIndex: libraryBranchIndex,
        ),
        EchoBackAction.popRootNavigator,
      );
      expect(
        resolveEchoBackAction(
          drawerOpen: false,
          rootCanPop: false,
          branchCanPop: true,
          currentBranchIndex: libraryBranchIndex,
        ),
        EchoBackAction.popBranchNavigator,
      );
      expect(
        resolveEchoBackAction(
          drawerOpen: false,
          rootCanPop: false,
          branchCanPop: false,
          currentBranchIndex: libraryBranchIndex,
        ),
        EchoBackAction.switchToDiscover,
      );
      expect(
        resolveEchoBackAction(
          drawerOpen: false,
          rootCanPop: false,
          branchCanPop: false,
          currentBranchIndex: discoverBranchIndex,
        ),
        EchoBackAction.moveAppToBackground,
      );
    });
  });

  group('MainScaffold destination mapping', () {
    testWidgets('page drawer trigger is compact-only', (tester) async {
      Future<void> pumpAtWidth(double width) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Text(
                shouldShowPageDrawerTrigger(context) ? 'compact' : 'wide',
              ),
            ),
          ),
        );
        await tester.pump();
      }

      addTearDown(tester.view.reset);
      await pumpAtWidth(599);
      expect(find.text('compact'), findsOneWidget);

      await pumpAtWidth(600);
      expect(find.text('wide'), findsOneWidget);
    });

    testWidgets('expanded page headings use the shared back toolbar', (
      tester,
    ) async {
      Future<void> pumpAtWidth(double width) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: EchoTopBar.back(context: context, title: '全部歌曲'),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      addTearDown(tester.view.reset);
      await pumpAtWidth(1440);
      expect(
        tester.widget<EchoTopBar>(find.byType(EchoTopBar)).leading,
        isNull,
      );

      await pumpAtWidth(390);
      expect(
        tester.widget<EchoTopBar>(find.byType(EchoTopBar)).leading,
        isA<EchoIconButton>(),
      );
    });

    test(
      'desktop minimum width keeps the expanded navigation shell active',
      () {
        expect(
          echoDesktopMinimumWindowWidth,
          greaterThanOrEqualTo(EchoBreakpoints.standard.expanded),
        );
      },
    );

    test('keeps fixed branch indices while Explore is dynamically visible', () {
      expect(
        echoMainDestinations(
          showExploreTab: true,
        ).map((destination) => destination.branchIndex),
        <int>[
          discoverBranchIndex,
          exploreBranchIndex,
          libraryBranchIndex,
          catalogBranchIndex,
        ],
      );
      expect(
        echoMainDestinations(
          showExploreTab: false,
        ).map((destination) => destination.branchIndex),
        <int>[discoverBranchIndex, libraryBranchIndex, catalogBranchIndex],
      );
    });

    testWidgets('catalog stack survives tab switches with Explore hidden', (
      tester,
    ) async {
      final harness = await _pumpMainScaffold(tester);
      harness.showExplore.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('曲库'));
      await tester.pumpAndSettle();
      expect(find.text('Catalog root'), findsOneWidget);
      expect(
        harness.container.read(currentVisibleBranchIndexProvider),
        catalogBranchIndex,
      );
      harness.router.go('/catalog/detail');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('我的'));
      await tester.pumpAndSettle();
      expect(find.text('Library root'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('曲库'));
      await tester.pumpAndSettle();
      expect(find.text('Catalog detail'), findsOneWidget);
      harness.showExplore.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Catalog detail'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Catalog root'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home root'), findsOneWidget);
    });

    testWidgets('desktop sidebar exposes the requested grouped destinations', (
      tester,
    ) async {
      await _pumpMainScaffold(tester, size: const Size(1440, 900));

      expect(find.text('Desktop Music Flow'), findsOneWidget);

      for (final label in <String>[
        '发现',
        '音乐流',
        '搜索',
        '资料库',
        '全部歌曲',
        '歌手',
        '专辑',
        '个人收藏',
        '收藏歌曲',
        '收藏专辑',
        '收藏歌手',
        '我的歌单',
        '管理',
        '下载管理',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing $label');
      }
      await tester.scrollUntilVisible(
        find.text('离线下载'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('echo-expanded-navigation'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('离线下载'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('设置'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('echo-expanded-navigation'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('设置'), findsOneWidget);
      expect(find.bySemanticsLabel('我的'), findsNothing);
      expect(find.bySemanticsLabel('曲库'), findsNothing);
    });

    testWidgets(
      'desktop sidebar replaces primary destinations and back returns to Music Flow',
      (tester) async {
        await _pumpMainScaffold(tester, size: const Size(1440, 900));

        await tester.tap(
          find.byKey(const ValueKey<String>('echo-desktop-sidebar-songs')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Desktop songs'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('echo-desktop-sidebar-artists')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Desktop artists'), findsOneWidget);
        expect(find.text('Desktop songs'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey<String>('echo-desktop-sidebar-songs')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Desktop songs'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Desktop Music Flow'), findsOneWidget);
        expect(find.text('Desktop songs'), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Desktop Music Flow'), findsOneWidget);
      },
    );

    testWidgets('desktop detail routes share the global back stack', (
      tester,
    ) async {
      await _pumpMainScaffold(tester, size: const Size(1440, 900));

      await tester.tap(
        find.byKey(const ValueKey<String>('echo-desktop-sidebar-songs')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('open-desktop-detail')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Desktop detail'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Desktop songs'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('echo-desktop-navigation-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('echo-desktop-forward')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('echo-desktop-forward')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Desktop detail'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Desktop songs'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Desktop Music Flow'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('echo-desktop-sidebar-music-flow')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EchoIconButton>(
              find.byKey(const ValueKey<String>('echo-desktop-forward')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('desktop shortcuts respect text entry and Escape route order', (
      tester,
    ) async {
      await _pumpMainScaffold(tester, size: const Size(1440, 900));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Desktop search'), findsOneWidget);

      final searchField = find.byKey(
        const ValueKey<String>('desktop-search-input'),
      );
      await tester.tap(searchField);
      await tester.enterText(searchField, 'find me');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'find me',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('open-desktop-detail')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Desktop detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Desktop search'), findsOneWidget);
    });

    testWidgets('preserves branch stacks and resets a reselected branch', (
      tester,
    ) async {
      final harness = await _pumpMainScaffold(tester);

      harness.router.go('/home/detail');
      await tester.pumpAndSettle();
      expect(find.text('Home detail'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('我的'));
      await tester.pumpAndSettle();
      expect(find.text('Library root'), findsOneWidget);
      expect(
        harness.container.read(currentVisibleBranchIndexProvider),
        libraryBranchIndex,
      );

      await tester.tap(find.bySemanticsLabel('音乐流'));
      await tester.pumpAndSettle();
      expect(find.text('Home detail'), findsOneWidget);
      expect(
        harness.container.read(currentVisibleBranchIndexProvider),
        discoverBranchIndex,
      );

      await tester.tap(find.bySemanticsLabel('音乐流'));
      await tester.pumpAndSettle();
      expect(find.text('Home root'), findsOneWidget);
      expect(find.text('Home detail'), findsNothing);
    });

    testWidgets(
      'hiding active Explore falls back to Home and syncs visibility',
      (tester) async {
        final harness = await _pumpMainScaffold(tester);

        await tester.tap(find.bySemanticsLabel('探索'));
        await tester.pumpAndSettle();
        expect(find.text('Explore root'), findsOneWidget);
        expect(
          harness.container.read(currentVisibleBranchIndexProvider),
          exploreBranchIndex,
        );

        harness.router.go('/explore/detail');
        await tester.pumpAndSettle();
        expect(find.text('Explore detail'), findsOneWidget);

        harness.showExplore.value = false;
        await tester.pumpAndSettle();

        expect(find.text('Home root'), findsOneWidget);
        expect(find.bySemanticsLabel('探索'), findsNothing);
        expect(
          harness.container.read(currentVisibleBranchIndexProvider),
          discoverBranchIndex,
        );

        harness.showExplore.value = true;
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('探索'));
        await tester.pumpAndSettle();
        expect(find.text('Explore detail'), findsOneWidget);
        expect(
          harness.container.read(currentVisibleBranchIndexProvider),
          exploreBranchIndex,
        );
      },
    );
  });
}

Future<_MainScaffoldHarness> _pumpMainScaffold(
  WidgetTester tester, {
  Size size = const Size(390, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final showExplore = ValueNotifier<bool>(true);
  addTearDown(showExplore.dispose);
  final branchNavigatorKeys = <GlobalKey<NavigatorState>>[
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ValueListenableBuilder<bool>(
            valueListenable: showExplore,
            builder: (context, showExploreTab, child) {
              return MainScaffold(
                navigationShell: navigationShell,
                branchNavigatorKeys: branchNavigatorKeys,
                showExploreTabOverride: showExploreTab,
                showMiniPlayerOverride: false,
                networkStatusOverride: EchoNetworkStatus.online,
                drawerOverride: const SizedBox(width: 320),
                miniPlayerOverride: const SizedBox(height: 72),
                desktopRootOverride: const _BranchPage('Desktop Music Flow'),
                desktopPageBuilderOverride: (destinationId) =>
                    _DesktopDestinationPage(destinationId: destinationId),
              );
            },
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[discoverBranchIndex],
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) => const _BranchPage('Home root'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) =>
                        const _BranchPage('Home detail'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[exploreBranchIndex],
            routes: <RouteBase>[
              GoRoute(
                path: '/explore',
                builder: (context, state) => const _BranchPage('Explore root'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) =>
                        const _BranchPage('Explore detail'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[libraryBranchIndex],
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (context, state) => const _BranchPage('Library root'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[catalogBranchIndex],
            routes: <RouteBase>[
              GoRoute(
                path: '/catalog',
                builder: (context, state) => const _BranchPage('Catalog root'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) =>
                        const _BranchPage('Catalog detail'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return _MainScaffoldHarness(
    router: router,
    container: container,
    showExplore: showExplore,
  );
}

class _MainScaffoldHarness {
  const _MainScaffoldHarness({
    required this.router,
    required this.container,
    required this.showExplore,
  });

  final GoRouter router;
  final ProviderContainer container;
  final ValueNotifier<bool> showExplore;
}

class _BranchPage extends StatelessWidget {
  const _BranchPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _DesktopDestinationPage extends StatelessWidget {
  const _DesktopDestinationPage({required this.destinationId});

  final String destinationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Desktop $destinationId'),
            if (destinationId == 'search')
              const TextField(key: ValueKey<String>('desktop-search-input')),
            ElevatedButton(
              key: const ValueKey<String>('open-desktop-detail'),
              onPressed: () => Navigator.of(context).push<void>(
                EchoPageRoute<void>(
                  context: context,
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Desktop detail')),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ],
        ),
      ),
    );
  }
}
