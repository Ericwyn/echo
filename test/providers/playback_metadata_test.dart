import 'package:audio_service/audio_service.dart';
import 'package:echoes/core/services/audio_media_item_mapper.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:echoes/providers/player/playback_metadata.dart';
import 'package:echoes/providers/player/player_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared metadata normalizes missing labels and invalid duration', () {
    final metadata = PlaybackMetadata.fromSong(
      Song(id: 'track-1', title: ' ', artist: ' ', album: '', duration: 0),
    );

    expect(metadata.songId, 'track-1');
    expect(metadata.title, 'Unknown Title');
    expect(metadata.artist, 'Unknown Artist');
    expect(metadata.album, 'Unknown Album');
    expect(metadata.duration, isNull);
  });

  test('snapshot and AudioService item use the same resolved metadata', () {
    final song = Song(
      id: 'track-2',
      title: ' Shared title ',
      artist: null,
      album: null,
      duration: null,
    );
    const duration = Duration(minutes: 3, seconds: 12);
    final playerState = PlayerState(
      currentSong: song,
      queue: <Song>[song],
      currentIndex: 0,
      duration: duration,
    );
    final snapshot = PlaybackSnapshot.fromState(playerState);
    final metadata = PlaybackMetadata.fromSong(
      song,
      durationOverride: playerState.duration,
    );
    final artworkUri = Uri.file('/tmp/echo-cover.png');
    final mediaItem = buildAudioMediaItem(metadata, artworkUri: artworkUri);

    expect(snapshot.songId, mediaItem.id);
    expect(snapshot.title, mediaItem.title);
    expect(snapshot.artist, mediaItem.artist);
    expect(snapshot.album, mediaItem.album);
    expect(snapshot.duration, mediaItem.duration);
    expect(snapshot.artworkReference, metadata.artworkReference);
    expect(mediaItem.artUri, artworkUri);
  });

  test('snapshot with no current song exposes empty metadata', () {
    final snapshot = PlaybackSnapshot.fromState(PlayerState());

    expect(snapshot.songId, isNull);
    expect(snapshot.title, isEmpty);
    expect(snapshot.artist, isEmpty);
    expect(snapshot.album, isEmpty);
    expect(snapshot.duration, Duration.zero);
    expect(snapshot.canSeek, isFalse);
  });
}
