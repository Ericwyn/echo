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
    expect(find.text('音量'), findsNothing);
    expect(find.text('静音'), findsNothing);
    expect(find.byTooltip('静音'), findsOneWidget);
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

  testWidgets('volume popup icon toggles mute without a separate menu item', (
    tester,
  ) async {
    final song = Song(id: 'song-1', title: 'Song');
    final notifier = TestPlayerNotifier(
      PlayerState(
        currentSong: song,
        queue: <Song>[song],
        currentIndex: 0,
        duration: const Duration(minutes: 3),
        userVolume: 0.6,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[playerProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: _VolumeControlTestHost(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('音量控制'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('静音'));
    await tester.pumpAndSettle();
    expect(notifier.state.isMuted, isTrue);
    expect(find.byTooltip('恢复音量'), findsOneWidget);
  });
}

class _VolumeControlTestHost extends StatelessWidget {
  const _VolumeControlTestHost();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1280,
    height: DesktopPlaybackBar.height,
    child: DesktopPlaybackBar(onOpenWorkspace: (_) {}),
  );
}
