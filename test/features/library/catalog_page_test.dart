import 'package:dio/dio.dart';
import 'package:echoes/core/design/echo_design.dart';
import 'package:echoes/core/network/address_pool.dart';
import 'package:echoes/core/network/connectivity_monitor.dart';
import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/repositories/music_repository.dart';
import 'package:echoes/features/library/pages/album_list_page.dart';
import 'package:echoes/features/library/pages/artist_list_page.dart';
import 'package:echoes/features/library/pages/catalog_page.dart';
import 'package:echoes/features/library/pages/library_page.dart';
import 'package:echoes/features/library/pages/song_list_page.dart';
import 'package:echoes/features/settings/pages/playback_stats_page.dart';
import 'package:echoes/providers/api_provider.dart';
import 'package:echoes/providers/music_provider.dart';
import 'package:echoes/providers/navigation_provider.dart';
import 'package:echoes/providers/playback_stats_provider.dart';
import 'package:echoes/providers/playlist_provider.dart';
import 'package:echoes/widgets/visible_remote_retry_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPage(
    WidgetTester tester, {
    Widget page = const CatalogPage(),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final monitor = ConnectivityMonitor(AddressPool(Dio()));
    addTearDown(monitor.stop);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityMonitorProvider.overrideWithValue(monitor),
          allSongsProvider.overrideWith((ref) async => []),
          allAlbumsProvider.overrideWith((ref) async => []),
          allArtistsProvider.overrideWith((ref) async => []),
          playlistsProvider.overrideWith((ref) async => []),
          starredProvider.overrideWith(
            (ref) async => StarredResult(songs: [], albums: [], artists: []),
          ),
          playbackStatsProvider.overrideWith(
            (ref) async => throw StateError('Test stats unavailable'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: EchoShellObstructionScope(bottom: 136, child: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'catalog groups browse destinations and statistics with bottom clearance',
    (tester) async {
      await pumpPage(tester, textScale: 2);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        (list.padding! as EdgeInsets).bottom,
        EchoSpacing.standard.xxl + 136,
      );
      for (final label in ['统计', '统计信息', '完整曲库', '全部歌曲', '按专辑浏览', '按歌手浏览']) {
        await tester.scrollUntilVisible(find.text(label), 120);
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('统计')).dy,
        lessThan(tester.getTopLeft(find.text('完整曲库')).dy),
      );
      expect(
        tester.getTopLeft(find.text('全部歌曲')).dy,
        greaterThan(tester.getTopLeft(find.text('统计信息')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'each catalog entry opens its existing page and returns to catalog',
    (tester) async {
      await pumpPage(tester);
      for (final entry in <String, Type>{
        '全部歌曲': SongListPage,
        '按专辑浏览': AlbumListPage,
        '按歌手浏览': ArtistListPage,
        '统计信息': PlaybackStatsPage,
      }.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        final retry = tester.widget<VisibleRemoteRetryScope>(
          find.byType(VisibleRemoteRetryScope),
        );
        expect(retry.branchIndex, catalogBranchIndex);
        await tester.tap(find.bySemanticsLabel('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(CatalogPage), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal tab retains collections and playlists without full catalog',
    (tester) async {
      await pumpPage(tester, page: const LibraryPage());
      expect(find.text('我的'), findsOneWidget);
      expect(find.text('收藏歌曲'), findsOneWidget);
      expect(find.text('我的歌单'), findsOneWidget);
      expect(find.text('全部歌曲'), findsNothing);
      expect(find.text('浏览完整曲库'), findsNothing);
    },
  );

  testWidgets('playlist sort and create actions share one aligned row', (
    tester,
  ) async {
    await pumpPage(tester, page: const LibraryPage());
    final actions = find
        .byKey(const ValueKey<String>('playlist-section-actions'))
        .first;
    final sort = find.descendant(
      of: actions,
      matching: find.bySemanticsLabel('歌单排序：默认顺序'),
    );
    final create = find.descendant(
      of: actions,
      matching: find.bySemanticsLabel('新建歌单'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(actions, findsOneWidget);
    expect(
      tester.getCenter(sort).dy,
      closeTo(tester.getCenter(create).dy, 0.01),
    );
    expect(tester.getCenter(sort).dx, lessThan(tester.getCenter(create).dx));
    expect(tester.takeException(), isNull);
  });
}
