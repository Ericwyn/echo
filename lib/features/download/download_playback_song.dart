import '../../data/models/download_task.dart';
import '../../data/models/song.dart';

/// The completed download may have a better artwork reference than getSong.
/// Preserve that reference when handing the song to the shared player.
Song songWithDownloadArtwork(Song song, DownloadTask task) {
  assert(song.id == task.songId);
  final coverArt = task.coverArt?.trim();
  if (coverArt == null || coverArt.isEmpty || coverArt == song.coverArt) {
    return song;
  }
  return song.copyWith(coverArt: coverArt);
}
