import 'package:just_audio/just_audio.dart' show LoopMode, ProcessingState;
import 'package:flutter/foundation.dart' show immutable;

import 'player_state.dart';
import 'playback_metadata.dart';

/// Stable playback controls consumed by both the Flutter UI and desktop adapters.
/// Implementations delegate to the existing player state machine; they must not
/// own or create an audio engine.
abstract interface class PlaybackCommands {
  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> setUserVolume(double volume);
  Future<void> setMuted(bool muted);
  Future<void> setPlaybackMode(PlaybackMode mode, {bool persist = true});
  Future<void> setLoopMode(LoopMode mode);
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> skipToQueueEntry(String entryId);
  void removeQueueEntry(String entryId);
  void reorderQueue(int oldIndex, int newIndex);
}

/// Immutable, platform-neutral view of the current playback session.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.songId,
    required this.entryId,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkReference,
    required this.position,
    this.positionSeekRevision = 0,
    required this.duration,
    required this.isPlaying,
    required this.playbackRequested,
    required this.isStopped,
    required this.isLoading,
    required this.hasError,
    required this.canPlay,
    required this.canPause,
    required this.canGoNext,
    required this.canGoPrevious,
    required this.canSeek,
    required this.volume,
    required this.isMuted,
    required this.loopMode,
    required this.shuffleEnabled,
  });

  factory PlaybackSnapshot.fromState(
    PlayerState state, {
    bool? playbackRequested,
    int positionSeekRevision = 0,
  }) {
    final song = state.currentSong;
    final requested = playbackRequested ?? state.isPlaying;
    final metadata = song == null ? null : PlaybackMetadata.fromSong(song);
    final duration = state.duration > Duration.zero
        ? state.duration
        : metadata?.duration ?? Duration.zero;
    final hasSong = song != null;
    return PlaybackSnapshot(
      songId: song?.id,
      entryId: state.currentEntryId,
      title: metadata?.title ?? '',
      artist: metadata?.artist ?? '',
      album: metadata?.album ?? '',
      artworkReference: metadata?.artworkReference,
      position: state.position,
      positionSeekRevision: positionSeekRevision,
      duration: duration,
      isPlaying: state.isPlaying,
      playbackRequested: requested,
      isStopped:
          song == null ||
          (state.processingState == ProcessingState.idle && !requested),
      isLoading: state.isLoading,
      hasError: state.hasPlaybackError,
      canPlay: hasSong && !state.isLoading,
      canPause: state.isPlaying,
      canGoNext: state.hasNext,
      canGoPrevious: state.hasPrevious,
      canSeek: hasSong && duration > Duration.zero,
      volume: state.userVolume,
      isMuted: state.isMuted,
      loopMode: state.loopMode,
      shuffleEnabled: state.shuffleEnabled,
    );
  }

  final String? songId;
  final String? entryId;
  final String title;
  final String artist;
  final String album;
  final String? artworkReference;
  final Duration position;

  /// Increments after a seek completes, distinguishing seeks from normal
  /// position updates even when snapshots arrive late.
  final int positionSeekRevision;
  final Duration duration;
  final bool isPlaying;
  final bool playbackRequested;
  final bool isStopped;
  final bool isLoading;
  final bool hasError;
  final bool canPlay;
  final bool canPause;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool canSeek;
  final double volume;
  final bool isMuted;
  final LoopMode loopMode;
  final bool shuffleEnabled;
}
