import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:flutter/foundation.dart' show immutable;

import 'player_state.dart';

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
    required this.duration,
    required this.isPlaying,
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

  factory PlaybackSnapshot.fromState(PlayerState state) {
    final song = state.currentSong;
    final duration = state.duration > Duration.zero
        ? state.duration
        : Duration(seconds: song?.duration ?? 0);
    final hasSong = song != null;
    return PlaybackSnapshot(
      songId: song?.id,
      entryId: state.currentEntryId,
      title: song?.title ?? '',
      artist: song?.artist ?? '',
      album: song?.album ?? '',
      artworkReference: song?.artworkReference,
      position: state.position,
      duration: duration,
      isPlaying: state.isPlaying,
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
  final Duration duration;
  final bool isPlaying;
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
