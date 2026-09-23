import 'package:echoes/data/models/song.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:echoes/providers/player/player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode, ProcessingState;

void main() {
  group('PlaybackSnapshot.fromState', () {
    test('projects active entry, controls, position and user volume', () {
      final first = Song(
        id: 'track-1',
        title: 'First',
        artist: 'Artist',
        duration: 180,
      );
      final second = Song(id: 'track-2', title: 'Second');
      final state = PlayerState(
        currentSong: first,
        queue: <Song>[first, second],
        currentIndex: 0,
        isPlaying: true,
        processingState: ProcessingState.ready,
        position: const Duration(seconds: 42),
        bufferedPosition: const Duration(seconds: 68),
        duration: const Duration(minutes: 3),
        loopMode: LoopMode.off,
        userVolume: 0.2,
        isMuted: false,
      );

      final snapshot = PlaybackSnapshot.fromState(
        state,
        libraryId: 'library-a',
        sourceGeneration: 11,
        positionSeekRevision: 7,
      );

      expect(snapshot.libraryId, 'library-a');
      expect(snapshot.sourceGeneration, 11);
      expect(snapshot.songId, first.id);
      expect(snapshot.entryId, state.currentEntryId);
      expect(snapshot.title, first.title);
      expect(snapshot.position, const Duration(seconds: 42));
      expect(snapshot.bufferedPosition, const Duration(seconds: 68));
      expect(snapshot.positionSeekRevision, 7);
      expect(snapshot.duration, const Duration(minutes: 3));
      expect(snapshot.isPlaying, isTrue);
      expect(snapshot.isStopped, isFalse);
      expect(snapshot.canPlay, isTrue);
      expect(snapshot.canPause, isTrue);
      expect(snapshot.canGoPrevious, isFalse);
      expect(snapshot.canGoNext, isTrue);
      expect(snapshot.canSeek, isTrue);
      expect(snapshot.volume, 0.2);
      expect(snapshot.isMuted, isFalse);
    });

    test('keeps a pending play request distinct from a stopped session', () {
      final state = PlayerState(
        currentSong: Song(id: 'track-1', title: 'First'),
        processingState: ProcessingState.idle,
      );

      final snapshot = PlaybackSnapshot.fromState(
        state,
        playbackRequested: true,
      );

      expect(snapshot.isPlaying, isFalse);
      expect(snapshot.playbackRequested, isTrue);
      expect(snapshot.isStopped, isFalse);
    });

    test('loading disables play while an error remains exposed separately', () {
      final song = Song(id: 'track-1', title: 'First');
      final loading = PlaybackSnapshot.fromState(
        PlayerState(
          currentSong: song,
          isChangingSource: true,
          processingState: ProcessingState.loading,
        ),
      );
      final failed = PlaybackSnapshot.fromState(
        PlayerState(currentSong: song, hasPlaybackError: true),
      );

      expect(loading.isLoading, isTrue);
      expect(loading.canPlay, isFalse);
      expect(loading.hasError, isFalse);
      expect(failed.hasError, isTrue);
      expect(failed.canPlay, isTrue);
    });
  });
}
