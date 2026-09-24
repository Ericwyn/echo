import 'package:echoes/core/utils/cover_ref_security.dart';
import 'package:echoes/data/models/download_task.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/download/download_playback_song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('download playback keeps the task artwork selected for the song', () {
    final artwork = toTrustedCoverUrlRef('https://art.example/cover.jpg');
    final song = Song(
      id: 'song-1',
      title: 'Downloaded song',
      coverArt: 'server-cover',
    );
    final task = DownloadTask(
      id: 'task-1',
      libraryId: 'library-1',
      songId: song.id,
      title: song.title,
      coverArt: artwork,
      createdAt: 1,
    );

    final playbackSong = songWithDownloadArtwork(song, task);
    expect(playbackSong.artworkReference, artwork);
    expect(playbackSong.title, song.title);
    expect(song.artworkReference, 'server-cover');
  });

  test('download playback retains server artwork when task has none', () {
    final song = Song(id: 'song-1', title: 'Song', coverArt: 'server-cover');
    final task = DownloadTask(
      id: 'task-1',
      libraryId: 'library-1',
      songId: song.id,
      title: song.title,
      createdAt: 1,
    );

    expect(songWithDownloadArtwork(song, task), same(song));
  });
}
