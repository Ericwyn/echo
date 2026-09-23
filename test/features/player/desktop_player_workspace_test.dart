import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/core/design/tokens/echo_colors.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/player/pages/desktop_player_workspace.dart';
import 'package:echoes/features/player/widgets/player_backdrop.dart';
import 'package:echoes/providers/lyrics_cover_provider.dart';
import 'package:echoes/providers/palette_provider.dart';
import 'package:echoes/providers/player_provider.dart';
import 'package:echoes/widgets/song_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_player_notifier.dart';

void main() {
  testWidgets('desktop lyrics stage uses artwork visuals and readable ink', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final song = Song(
      id: 'desktop-current',
      title: 'Desktop contrast song',
      artist: 'Echo Artist',
      album: 'Echo Album',
    );
    final visuals = EchoMediaVisuals.fallback(seed: const Color(0xFF187EA5));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            (ref) => TestPlayerNotifier(
              PlayerState(
                currentSong: song,
                queue: <Song>[song],
                currentIndex: 0,
              ),
            ),
          ),
          currentLyricsProvider.overrideWith((ref) async => null),
          currentSongPaletteProvider.overrideWith((ref) async => null),
          resolvedCurrentSongMediaVisualsProvider.overrideWithValue(visuals),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopPlayerWorkspace(
              panel: DesktopPlayerPanel.lyrics,
              onPanelChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backdrop = tester.widget<EchoPlayerBackdrop>(
      find.byType(EchoPlayerBackdrop),
    );
    expect(backdrop.visuals, same(visuals));
    expect(backdrop.decoration.gradient, isNotNull);

    final title = tester.widget<Text>(find.text(song.title).first);
    expect(title.style?.color, visuals.foreground);
    final emptyLyrics = tester.widget<Text>(find.text('暂无歌词'));
    expect(emptyLyrics.style?.color, visuals.foreground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled dynamic background follows the active theme', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final song = Song(
      id: 'desktop-static-background',
      title: 'Static background song',
    );
    final theme = AppTheme.light();
    final themeColors = theme.extension<EchoColors>()!;
    final themeVisuals = EchoMediaVisuals.fromThemeColors(themeColors);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            (ref) => TestPlayerNotifier(
              PlayerState(
                currentSong: song,
                queue: <Song>[song],
                currentIndex: 0,
              ),
            ),
          ),
          currentLyricsProvider.overrideWith((ref) async => null),
          playerSurfaceMediaVisualsProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: DesktopPlayerWorkspace(
              panel: DesktopPlayerPanel.lyrics,
              onPanelChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backdrop = tester.widget<EchoPlayerBackdrop>(
      find.byType(EchoPlayerBackdrop),
    );
    expect(backdrop.visuals, themeVisuals);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop workspace uses a compact header when space is tight', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 460);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final song = Song(
      id: 'desktop-compact-current',
      title: 'Compact desktop song',
      artist: 'Echo Artist',
      album: 'Echo Album',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            (ref) => TestPlayerNotifier(
              PlayerState(
                currentSong: song,
                queue: <Song>[song],
                currentIndex: 0,
              ),
            ),
          ),
          currentLyricsProvider.overrideWith((ref) async => null),
          currentSongPaletteProvider.overrideWith((ref) async => null),
          resolvedCurrentSongMediaVisualsProvider.overrideWithValue(
            EchoMediaVisuals.fallback(seed: const Color(0xFF187EA5)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopPlayerWorkspace(
              panel: DesktopPlayerPanel.lyrics,
              onPanelChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('echo-desktop-workspace-compact-header'),
      ),
      findsOneWidget,
    );
    expect(find.text('歌词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop queue selection survives switching workspace panels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final songs = <Song>[
      Song(id: 'queue-first', title: 'Queue first'),
      Song(id: 'queue-second', title: 'Queue second'),
    ];
    final player = TestPlayerNotifier(
      PlayerState(currentSong: songs.first, queue: songs, currentIndex: 0),
    );
    var panel = DesktopPlayerPanel.queue;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith((ref) => player),
          currentLyricsProvider.overrideWith((ref) async => null),
          currentSongPaletteProvider.overrideWith((ref) async => null),
          resolvedCurrentSongMediaVisualsProvider.overrideWithValue(
            EchoMediaVisuals.fallback(seed: const Color(0xFF187EA5)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: DesktopPlayerWorkspace(
                panel: panel,
                onPanelChanged: (value) => setState(() => panel = value),
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final secondRow = find.ancestor(
      of: find.text('Queue second'),
      matching: find.byType(EchoSongRow),
    );
    await tester.tap(find.text('Queue second'));
    await tester.pumpAndSettle();
    expect(tester.widget<EchoSongRow>(secondRow).selected, isTrue);

    await tester.tap(find.widgetWithText(TextButton, '歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '播放队列'));
    await tester.pumpAndSettle();

    expect(tester.widget<EchoSongRow>(secondRow).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop queue can locate the current row after browsing away', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final songs = List<Song>.generate(
      40,
      (index) => Song(id: 'locate-$index', title: 'Locate track $index'),
      growable: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            (ref) => TestPlayerNotifier(
              PlayerState(
                currentSong: songs.first,
                queue: songs,
                currentIndex: 0,
              ),
            ),
          ),
          currentLyricsProvider.overrideWith((ref) async => null),
          currentSongPaletteProvider.overrideWith((ref) async => null),
          resolvedCurrentSongMediaVisualsProvider.overrideWithValue(
            EchoMediaVisuals.fallback(seed: const Color(0xFF187EA5)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopPlayerWorkspace(
              panel: DesktopPlayerPanel.queue,
              onPanelChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(songs.first.title), findsOneWidget);
    await tester.fling(
      find.byType(ReorderableListView),
      const Offset(0, -1800),
      3000,
    );
    await tester.pumpAndSettle();
    expect(find.text(songs.first.title), findsNothing);

    await tester.tap(find.text('定位当前'));
    await tester.pumpAndSettle();
    expect(find.text(songs.first.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
