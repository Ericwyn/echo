import 'package:dio/dio.dart';
import 'package:echoes/core/network/address_pool.dart';
import 'package:echoes/core/network/connectivity_monitor.dart';
import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/library/pages/song_list_page.dart';
import 'package:echoes/features/library/utils/library_sorting.dart';
import 'package:echoes/providers/api_provider.dart';
import 'package:echoes/providers/music_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('invalid saved all-songs sort falls back to alphabetical order', () {
    expect(
      parseAllSongsSortOption('removed-option'),
      SongSortOption.alphabeticalAsc,
    );
    expect(
      parseAllSongsSortOption(SongSortOption.updatedDesc.name),
      SongSortOption.updatedDesc,
    );
  });

  testWidgets('all-songs sort survives leaving and reopening the page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final connectivityMonitor = ConnectivityMonitor(AddressPool(Dio()));
    addTearDown(connectivityMonitor.stop);

    final songs = <Song>[
      Song(id: 'short', title: 'Short', duration: 30),
      Song(id: 'long', title: 'Long', duration: 300),
    ];

    Widget buildPage() => ProviderScope(
      overrides: <Override>[
        connectivityMonitorProvider.overrideWithValue(connectivityMonitor),
        allSongsProvider.overrideWith((ref) async => songs),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SongListPage()),
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('歌曲排序：字母 A-Z'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('时长从长到短'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('歌曲排序：时长从长到短'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'all_songs_sort_option',
      ),
      SongSortOption.durationDesc.name,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('歌曲排序：时长从长到短'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('song-list-sorted-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
