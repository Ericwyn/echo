import 'dart:async';

import 'package:flutter/services.dart';

import '../../providers/player/playback_contract.dart';

typedef WindowsArtworkResolver =
    Future<Uri?> Function(PlaybackSnapshot snapshot);
typedef WindowsArtworkPathResolver = String Function(Uri uri);

/// Thin Dart adapter for the native Windows SMTC bridge.
///
/// This class publishes playback state and forwards system actions only. The
/// audio engine and queue remain owned by [PlaybackCommands].
class WindowsSmtcService {
  WindowsSmtcService({
    required this.commands,
    required this.artworkResolver,
    MethodChannel? channel,
    WindowsArtworkPathResolver? artworkPathResolver,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _artworkPathResolver =
           artworkPathResolver ?? ((uri) => uri.toFilePath(windows: true));

  static const _channelName = 'echoes/windows_smtc';

  final PlaybackCommands commands;
  final WindowsArtworkResolver artworkResolver;
  final MethodChannel _channel;
  final WindowsArtworkPathResolver _artworkPathResolver;

  PlaybackSnapshot? _snapshot;
  Uri? _artworkUri;
  var _artworkGeneration = 0;
  var _started = false;
  var _disposed = false;

  bool get isStarted => _started;

  Future<void> start(PlaybackSnapshot initialSnapshot) async {
    if (_started) return;
    _disposed = false;
    _channel.setMethodCallHandler(_handleSystemCall);
    await _channel.invokeMethod<void>('initialize');

    // State listeners can deliver snapshots before native initialization has
    // completed. Publish the newest one unconditionally after initialization,
    // even when it matches the cached Dart snapshot.
    final firstSnapshot = _snapshot ?? initialSnapshot;
    _snapshot = null;
    _artworkUri = null;
    _started = true;
    await updateSnapshot(firstSnapshot);
  }

  Future<void> updateSnapshot(PlaybackSnapshot next) async {
    if (!_started || _disposed) {
      _snapshot = next;
      return;
    }

    final previous = _snapshot;
    final trackChanged =
        previous == null ||
        previous.libraryId != next.libraryId ||
        previous.sourceGeneration != next.sourceGeneration ||
        previous.songId != next.songId ||
        previous.entryId != next.entryId ||
        previous.artworkReference != next.artworkReference;
    final metadataChanged =
        trackChanged ||
        previous.title != next.title ||
        previous.artist != next.artist ||
        previous.album != next.album;
    _snapshot = next;

    if (trackChanged) {
      _artworkGeneration += 1;
      _artworkUri = null;
    }

    if (metadataChanged) {
      await _channel.invokeMethod<void>('updateMetadata', <String, Object?>{
        'title': next.title,
        'artist': next.artist,
        'album': next.album,
        'hasTrack': next.songId != null,
        'clearArtwork': trackChanged,
        'artworkGeneration': _artworkGeneration,
        'artworkPath': _artworkPath(_artworkUri),
      });
      if (trackChanged && next.artworkReference != null) {
        unawaited(_resolveArtwork(next, _artworkGeneration));
      }
    }

    if (_shouldPublishPlayback(previous, next, trackChanged)) {
      await _channel.invokeMethod<void>('updatePlayback', <String, Object?>{
        'status': _status(next),
        'positionMicroseconds': next.position.inMicroseconds,
        'durationMicroseconds': next.duration.inMicroseconds,
        'canPlay': next.canPlay,
        'canPause': next.canPause || next.playbackRequested,
        'canGoNext': next.canGoNext,
        'canGoPrevious': next.canGoPrevious,
        'canSeek': next.canSeek,
        'hasTrack': next.songId != null,
      });
    }
  }

  bool _shouldPublishPlayback(
    PlaybackSnapshot? previous,
    PlaybackSnapshot next,
    bool trackChanged,
  ) {
    if (trackChanged || previous == null) return true;
    return previous.playbackRequested != next.playbackRequested ||
        previous.isStopped != next.isStopped ||
        previous.isLoading != next.isLoading ||
        previous.canPlay != next.canPlay ||
        previous.canPause != next.canPause ||
        previous.canGoNext != next.canGoNext ||
        previous.canGoPrevious != next.canGoPrevious ||
        previous.canSeek != next.canSeek ||
        previous.duration != next.duration ||
        (next.position - previous.position).abs() >= const Duration(seconds: 2);
  }

  String _status(PlaybackSnapshot snapshot) {
    if (snapshot.isStopped) return 'stopped';
    if (snapshot.isLoading) return 'changing';
    return snapshot.playbackRequested ? 'playing' : 'paused';
  }

  String? _artworkPath(Uri? uri) {
    if (uri == null || uri.scheme != 'file') return null;
    return _artworkPathResolver(uri);
  }

  Future<void> _resolveArtwork(
    PlaybackSnapshot snapshot,
    int generation,
  ) async {
    try {
      final uri = await artworkResolver(snapshot);
      if (uri == null ||
          uri.scheme != 'file' ||
          !_isCurrentArtwork(snapshot, generation)) {
        return;
      }
      _artworkUri = uri;
      await _channel.invokeMethod<void>('updateArtwork', <String, Object?>{
        'artworkPath': _artworkPath(uri),
        'artworkGeneration': generation,
      });
    } catch (_) {
      // The media session can still publish metadata and transport controls.
    }
  }

  bool _isCurrentArtwork(PlaybackSnapshot snapshot, int generation) {
    final current = _snapshot;
    return !_disposed &&
        generation == _artworkGeneration &&
        current != null &&
        current.libraryId == snapshot.libraryId &&
        current.sourceGeneration == snapshot.sourceGeneration &&
        current.songId == snapshot.songId &&
        current.entryId == snapshot.entryId &&
        current.artworkReference == snapshot.artworkReference;
  }

  Future<void> _handleSystemCall(MethodCall call) async {
    if (call.method != 'onControl' || _disposed) return;
    final payload = call.arguments;
    if (payload is! Map) return;
    final type = payload['type'];
    switch (type) {
      case 'play':
        await commands.play();
      case 'pause':
        await commands.pause();
      case 'next':
        await commands.next();
      case 'previous':
        await commands.previous();
      case 'stop':
        await commands.stop();
      case 'seek':
        final position = payload['positionMicroseconds'];
        if (position is int) {
          await commands.seek(Duration(microseconds: position));
        }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    _artworkGeneration += 1;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {
      // The runner may already be shutting down.
    }
    _snapshot = null;
    _artworkUri = null;
  }
}
