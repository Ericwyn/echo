import 'package:just_audio/just_audio.dart';
import '../../../data/models/song.dart';
import '../../../data/models/audio_quality.dart';
import 'playback_queue_state.dart';

/// 播放来源
enum PlaybackSource {
  downloaded, // 已下载的本地文件
  cached, // 缓存的本地文件
  stream, // 在线流式播放
}

/// 播放模式
enum PlaybackMode { sequential, repeatAll, repeatOne, shuffle }

/// 播放器状态
class PlayerState {
  final PlaybackQueueState playbackQueue;
  final bool isPlaying;
  final ProcessingState processingState;
  final bool isSeeking;
  final bool isChangingSource;
  final bool hasPlaybackError;
  final Duration position;
  final Duration duration;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final double userVolume;
  final bool isMuted;
  final AudioQualityLevel? currentQuality;
  final PlaybackSource? playbackSource;
  final int currentBitRateKbps;
  final Duration bufferedPosition;

  PlayerState({
    Song? currentSong,
    List<Song> queue = const [],
    int currentIndex = 0,
    PlaybackQueueState? playbackQueue,
    this.isPlaying = false,
    this.processingState = ProcessingState.idle,
    this.isSeeking = false,
    this.isChangingSource = false,
    this.hasPlaybackError = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loopMode = LoopMode.all,
    this.shuffleEnabled = false,
    this.userVolume = 1,
    this.isMuted = false,
    this.currentQuality,
    this.playbackSource,
    this.currentBitRateKbps = 0,
    this.bufferedPosition = Duration.zero,
  }) : playbackQueue =
           playbackQueue ??
           PlaybackQueueState.fromSongs(
             queue.isEmpty && currentSong != null ? <Song>[currentSong] : queue,
             currentIndex: currentSong == null
                 ? null
                 : queue.isEmpty
                 ? 0
                 : currentIndex,
           );

  Song? get currentSong => playbackQueue.currentSong;
  List<Song> get queue => playbackQueue.songs;
  List<String> get queueEntryIds => playbackQueue.entryIds;
  String? get currentEntryId => playbackQueue.currentEntryId;
  int get currentIndex => playbackQueue.currentIndex;

  PlayerState copyWith({
    Object? currentSong = _keepValue,
    List<Song>? queue,
    int? currentIndex,
    PlaybackQueueState? playbackQueue,
    bool? isPlaying,
    ProcessingState? processingState,
    bool? isSeeking,
    bool? isChangingSource,
    bool? hasPlaybackError,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? shuffleEnabled,
    double? userVolume,
    bool? isMuted,
    Object? currentQuality = _keepValue,
    Object? playbackSource = _keepValue,
    int? currentBitRateKbps,
    Duration? bufferedPosition,
  }) {
    var nextQueue = playbackQueue ?? this.playbackQueue;
    final hasSongOverride = !identical(currentSong, _keepValue);
    final requestedSong = hasSongOverride
        ? currentSong as Song?
        : this.currentSong;

    if (playbackQueue == null &&
        queue != null &&
        !identical(queue, this.queue)) {
      if (queue.length == this.queue.length) {
        nextQueue = nextQueue.replaceVisibleSongs(queue);
      } else {
        var requestedIndex = currentIndex;
        if (requestedIndex == null && requestedSong != null) {
          requestedIndex = queue.indexWhere(
            (song) => song.id == requestedSong.id,
          );
        }
        nextQueue = PlaybackQueueState.fromSongs(
          queue,
          currentIndex: requestedSong == null ? null : requestedIndex,
        );
      }
    }

    if (playbackQueue == null) {
      if (hasSongOverride && requestedSong == null) {
        nextQueue = nextQueue.selectEntry(null);
      } else {
        final targetIndex = currentIndex ?? nextQueue.currentIndex;
        if (targetIndex >= 0 && targetIndex < nextQueue.length) {
          nextQueue = nextQueue.selectIndex(targetIndex);
          if (hasSongOverride && requestedSong != null) {
            nextQueue = nextQueue.updateEntrySong(
              nextQueue.currentEntryId!,
              requestedSong,
            );
          }
        }
      }
    }

    return PlayerState(
      playbackQueue: nextQueue,
      isPlaying: isPlaying ?? this.isPlaying,
      processingState: processingState ?? this.processingState,
      isSeeking: isSeeking ?? this.isSeeking,
      isChangingSource: isChangingSource ?? this.isChangingSource,
      hasPlaybackError: hasPlaybackError ?? this.hasPlaybackError,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      userVolume: userVolume ?? this.userVolume,
      isMuted: isMuted ?? this.isMuted,
      currentQuality: identical(currentQuality, _keepValue)
          ? this.currentQuality
          : currentQuality as AudioQualityLevel?,
      playbackSource: identical(playbackSource, _keepValue)
          ? this.playbackSource
          : playbackSource as PlaybackSource?,
      currentBitRateKbps: currentBitRateKbps ?? this.currentBitRateKbps,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
    );
  }

  bool get _hasValidCurrent =>
      currentSong != null && currentIndex >= 0 && currentIndex < queue.length;

  /// Loading is independent of the native play/pause flag: a seek may pause
  /// the engine while replacing its source, or keep playing while buffering.
  bool get isLoading =>
      !hasPlaybackError &&
      (isSeeking ||
          isChangingSource ||
          processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering);

  bool get hasNext {
    if (!_hasValidCurrent) return false;
    return shuffleEnabled ||
        loopMode != LoopMode.off ||
        currentIndex < queue.length - 1;
  }

  bool get hasPrevious {
    if (!_hasValidCurrent) return false;
    return shuffleEnabled || loopMode != LoopMode.off || currentIndex > 0;
  }
}

const Object _keepValue = Object();
