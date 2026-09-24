import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/player/widgets/desktop_playback_bar.dart';
import 'package:echoes/features/player/widgets/player_scrubber.dart';
import 'package:echoes/providers/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_player_notifier.dart';

void main() {
  testWidgets('volume slider opens from its button without a second bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final song = Song(id: 'song-1', title: 'Song');
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProvider.overrideWith(
            (ref) => TestPlayerNotifier(
              PlayerState(
                currentSong: song,
                queue: <Song>[song],
                currentIndex: 0,
                duration: const Duration(minutes: 3),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: DesktopPlaybackBar.height,
              child: DesktopPlaybackBar(onOpenWorkspace: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scrubbers = find.byType(EchoPlayerScrubber);
    expect(scrubbers, findsOneWidget);
    final volumeButton = find.bySemanticsLabel('音量控制');
    expect(volumeButton, findsOneWidget);
    await tester.tap(volumeButton);
    await tester.pumpAndSettle();
    expect(scrubbers, findsNWidgets(2));
    final playbackBarRect = tester.getRect(
      find.byKey(const ValueKey<String>('echo-desktop-playback-bar')),
    );
    final progressCenter = tester.getCenter(scrubbers.first);
    expect(
      progressCenter.dy,
      closeTo(tester.getCenter(find.text('3:00')).dy, 1),
    );
    expect(
      playbackBarRect.bottom - tester.getRect(scrubbers.first).bottom,
      greaterThan(8),
    );
    expect(find.text('3:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
