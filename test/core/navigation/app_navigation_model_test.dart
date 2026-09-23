import 'package:echoes/features/navigation/app_navigation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationModel', () {
    test('desktop destinations have stable unique IDs and page targets', () {
      final items = AppNavigationModel.desktopSidebar(showExploreTab: true);
      final ids = items.map((item) => item.id).toList(growable: false);

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, <String>[
        'music-flow',
        'explore',
        'search',
        'songs',
        'artists',
        'albums',
        'favorite-songs',
        'favorite-albums',
        'favorite-artists',
        'my-playlists',
        'downloads',
        'offline',
        'settings',
      ]);
      expect(items.every((item) => item.isDesktopDestination), isTrue);
    });

    test('phone shell and desktop sidebar share discover destinations', () {
      final phone = AppNavigationModel.primaryDestinations(
        showExploreTab: true,
      );
      final desktop = AppNavigationModel.desktopSidebar(showExploreTab: true);
      final desktopById = <String, AppNavigationItem>{
        for (final item in desktop) item.id: item,
      };

      expect(phone.map((item) => item.primaryLabel), <String>[
        '音乐流',
        '探索',
        '我的',
        '曲库',
      ]);
      expect(phone.first, same(desktopById['music-flow']));
      expect(phone[1], same(desktopById['explore']));
      expect(phone.every((item) => item.isPrimaryDestination), isTrue);
    });

    test(
      'Explore visibility and drawer management actions share definitions',
      () {
        final desktopWithoutExplore = AppNavigationModel.desktopSidebar(
          showExploreTab: false,
        );
        final desktopById = <String, AppNavigationItem>{
          for (final item in desktopWithoutExplore) item.id: item,
        };
        final drawerItems = AppNavigationModel.drawerActions;
        final drawerById = <String, AppNavigationItem>{
          for (final item in drawerItems) item.id: item,
        };

        expect(desktopById.containsKey('explore'), isFalse);
        expect(
          drawerById.keys,
          containsAll(<String>[
            'route-selection',
            'downloads',
            'offline',
            'settings',
          ]),
        );
        for (final id in <String>['downloads', 'offline', 'settings']) {
          expect(drawerById[id], same(desktopById[id]));
        }
        expect(drawerById['route-selection']!.pageBuilder, isNull);
        expect(
          drawerById.values
              .where((item) => item.id != 'route-selection')
              .every((item) => item.pageBuilder != null),
          isTrue,
        );
      },
    );
  });
}
