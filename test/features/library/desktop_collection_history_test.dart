import 'dart:ui' show Tristate;

import 'package:echoes/core/design/components/echo_page_route.dart';
import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/models/album.dart';
import 'package:echoes/data/models/artist.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/data/repositories/music_repository.dart';
import 'package:echoes/features/library/pages/artist_detail_page.dart';
import 'package:echoes/features/library/pages/starred_page.dart';
import 'package:echoes/providers/music_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final artist = Artist(id: 'artist-1', name: 'History artist', albumCount: 1);
  final album = Album(
    id: 'album-1',
    name: 'History album',
    artist: 'History artist',
    songCount: 1,
    duration: 180,
  );
  final song = Song(
    id: 'song-1',
    title: 'History song',
    artist: 'History artist',
    album: 'History album',
    duration: 180,
  );

  testWidgets('desktop forward restores the selected starred tab', (
    tester,
  ) async {
    late EchoPageRoute<void> pageRoute;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          starredProvider.overrideWith(
            (ref) async => StarredResult(
              artists: <Artist>[artist],
              albums: <Album>[album],
              songs: <Song>[song],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: <Widget>[
                  TextButton(
                    key: const ValueKey<String>('open-starred-history-route'),
                    onPressed: () {
                      pageRoute = EchoPageRoute<void>(
                        context: context,
                        builder: (_) => const StarredPage(),
                      );
                      Navigator.of(context).push<void>(pageRoute);
                    },
                    child: const Text('Open starred'),
                  ),
                  TextButton(
                    key: const ValueKey<String>(
                      'forward-starred-history-route',
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).push<void>(pageRoute.recreate(context)),
                    child: const Text('Forward starred'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open-starred-history-route')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('专辑收藏'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('专辑收藏'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('forward-starred-history-route')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('专辑收藏'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('desktop forward restores the selected artist detail section', (
    tester,
  ) async {
    late EchoPageRoute<void> pageRoute;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          artistDetailProvider(artist.id).overrideWith(
            (ref) async => ArtistDetail(
              artist: artist,
              albums: <Album>[album],
              songs: <Song>[song],
            ),
          ),
          topSongsByArtistProvider(
            artist.name,
          ).overrideWith((ref) async => <Song>[]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: <Widget>[
                  TextButton(
                    key: const ValueKey<String>('open-artist-history-route'),
                    onPressed: () {
                      pageRoute = EchoPageRoute<void>(
                        context: context,
                        builder: (_) => ArtistDetailPage(artistId: artist.id),
                      );
                      Navigator.of(context).push<void>(pageRoute);
                    },
                    child: const Text('Open artist'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('forward-artist-history-route'),
                    onPressed: () => Navigator.of(
                      context,
                    ).push<void>(pageRoute.recreate(context)),
                    child: const Text('Forward artist'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open-artist-history-route')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('专辑'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('专辑'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('forward-artist-history-route')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('专辑'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });
}
