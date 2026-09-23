import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/player/pages/desktop_player_workspace.dart';
import 'package:echoes/features/player/widgets/player_backdrop.dart';
import 'package:echoes/providers/lyrics_cover_provider.dart';
import 'package:echoes/providers/palette_provider.dart';
import 'package:echoes/providers/player_provider.dart';
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
}
