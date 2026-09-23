import '../../providers/player/playback_contract.dart';

/// Playback capabilities presented by the desktop tray menu.
///
/// Position and duration are intentionally omitted so normal progress updates
/// do not rebuild the native tray menu.
class DesktopTrayMenuState {
  const DesktopTrayMenuState({
    required this.playPauseLabel,
    required this.canTogglePlayback,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  const DesktopTrayMenuState.empty()
    : playPauseLabel = '播放',
      canTogglePlayback = false,
      canGoPrevious = false,
      canGoNext = false;

  factory DesktopTrayMenuState.fromSnapshot(PlaybackSnapshot snapshot) {
    final hasTrack = snapshot.songId != null;
    return DesktopTrayMenuState(
      playPauseLabel: snapshot.playbackRequested ? '暂停' : '播放',
      canTogglePlayback:
          hasTrack &&
          (snapshot.canPlay || snapshot.canPause || snapshot.playbackRequested),
      canGoPrevious: hasTrack && snapshot.canGoPrevious,
      canGoNext: hasTrack && snapshot.canGoNext,
    );
  }

  final String playPauseLabel;
  final bool canTogglePlayback;
  final bool canGoPrevious;
  final bool canGoNext;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopTrayMenuState &&
          playPauseLabel == other.playPauseLabel &&
          canTogglePlayback == other.canTogglePlayback &&
          canGoPrevious == other.canGoPrevious &&
          canGoNext == other.canGoNext;

  @override
  int get hashCode =>
      Object.hash(playPauseLabel, canTogglePlayback, canGoPrevious, canGoNext);
}
