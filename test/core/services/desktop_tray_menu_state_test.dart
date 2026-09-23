import 'package:echoes/core/services/desktop_tray_menu_state.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

void main() {
  PlaybackSnapshot snapshot({
    String? songId = 'song-1',
    Duration position = Duration.zero,
    bool playbackRequested = false,
    bool canPlay = true,
    bool canPause = false,
    bool canGoPrevious = false,
    bool canGoNext = false,
  }) => PlaybackSnapshot(
    songId: songId,
    entryId: songId == null ? null : 'entry-1',
    title: songId == null ? '' : 'Track',
    artist: '',
    album: '',
    artworkReference: null,
    position: position,
    duration: const Duration(minutes: 3),
    isPlaying: playbackRequested,
    playbackRequested: playbackRequested,
    isStopped: songId == null,
    isLoading: false,
    hasError: false,
    canPlay: canPlay,
    canPause: canPause,
    canGoNext: canGoNext,
    canGoPrevious: canGoPrevious,
    canSeek: songId != null,
    volume: 1,
    isMuted: false,
    loopMode: LoopMode.off,
    shuffleEnabled: false,
  );

  test('shows the action state and previous/next capabilities', () {
    final state = DesktopTrayMenuState.fromSnapshot(
      snapshot(
        playbackRequested: true,
        canPlay: false,
        canPause: true,
        canGoPrevious: true,
      ),
    );

    expect(state.playPauseLabel, '暂停');
    expect(state.canTogglePlayback, isTrue);
    expect(state.canGoPrevious, isTrue);
    expect(state.canGoNext, isFalse);
  });

  test(
    'ignores position-only updates when deciding whether menu state changed',
    () {
      final before = DesktopTrayMenuState.fromSnapshot(snapshot());
      final after = DesktopTrayMenuState.fromSnapshot(
        snapshot(position: const Duration(seconds: 42)),
      );

      expect(after, before);
    },
  );

  test('disables transport actions when there is no current song', () {
    final state = DesktopTrayMenuState.fromSnapshot(
      snapshot(songId: null, canGoPrevious: true, canGoNext: true),
    );

    expect(state.playPauseLabel, '播放');
    expect(state.canTogglePlayback, isFalse);
    expect(state.canGoPrevious, isFalse);
    expect(state.canGoNext, isFalse);
  });
}
