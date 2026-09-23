import 'package:flutter/foundation.dart' show immutable;

import '../../data/models/song.dart';

/// Platform-neutral metadata shared by system media sessions and the player UI.
@immutable
class PlaybackMetadata {
  const PlaybackMetadata({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artworkReference,
  });

  factory PlaybackMetadata.fromSong(Song song, {Duration? durationOverride}) {
    final artist = song.artist?.trim();
    final album = song.album?.trim();
    final durationSeconds = song.duration;
    return PlaybackMetadata(
      songId: song.id,
      title: song.title.trim().isEmpty ? 'Unknown Title' : song.title.trim(),
      artist: artist == null || artist.isEmpty ? 'Unknown Artist' : artist,
      album: album == null || album.isEmpty ? 'Unknown Album' : album,
      duration: durationOverride != null && durationOverride > Duration.zero
          ? durationOverride
          : durationSeconds != null && durationSeconds > 0
          ? Duration(seconds: durationSeconds)
          : null,
      artworkReference: song.artworkReference,
    );
  }

  final String songId;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? artworkReference;
}
