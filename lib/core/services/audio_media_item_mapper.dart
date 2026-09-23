import 'package:audio_service/audio_service.dart';

import '../../providers/player/playback_metadata.dart';

/// Converts shared player metadata to the Android/audio_service media model.
MediaItem buildAudioMediaItem(PlaybackMetadata metadata, {Uri? artworkUri}) =>
    MediaItem(
      id: metadata.songId,
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      duration: metadata.duration,
      artUri: artworkUri,
    );
