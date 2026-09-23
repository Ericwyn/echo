import 'dart:async';

import 'package:echoes/core/services/windows_smtc_service.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

const _channel = MethodChannel('echoes/windows_smtc');
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'publishes shared metadata and sends only a cached local artwork path',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));

      final service = WindowsSmtcService(
        commands: _RecordingPlaybackCommands(),
        artworkResolver: (_) async => Uri.file('/tmp/current-cover.png'),
        channel: _channel,
        artworkPathResolver: (uri) => uri.toFilePath(),
      );

      // StateNotifier may emit the current state before the native channel has
      // finished initializing. The first native publication must still carry
      // that snapshot and its artwork request.
      await service.updateSnapshot(_snapshot());
      await service.start(_snapshot());
      await pumpEventQueue();

      expect(calls.first.method, 'initialize');
      final metadata = calls.singleWhere(
        (call) => call.method == 'updateMetadata',
      );
      expect((metadata.arguments as Map)['title'], 'Echo Song');
      expect((metadata.arguments as Map)['artworkPath'], isNull);
      final artwork = calls.singleWhere(
        (call) => call.method == 'updateArtwork',
      );
      expect(
        (artwork.arguments as Map)['artworkPath'],
        '/tmp/current-cover.png',
      );
      expect(
        calls.every(
          (call) =>
              !(call.arguments is Map &&
                  (call.arguments as Map).values.any(
                    (value) =>
                        value is String && value.contains('example.invalid'),
                  )),
        ),
        isTrue,
      );

      await service.dispose();
      expect(calls.last.method, 'dispose');
    },
  );

  test('library changes reject late artwork and route SMTC commands', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));

    final lateArtwork = Completer<Uri?>();
    final commands = _RecordingPlaybackCommands();
    final service = WindowsSmtcService(
      commands: commands,
      artworkResolver: (snapshot) => snapshot.libraryId == 'library-a'
          ? lateArtwork.future
          : Future<Uri?>.value(Uri.file('/tmp/new-cover.png')),
      channel: _channel,
      artworkPathResolver: (uri) => uri.toFilePath(),
    );

    await service.start(_snapshot(libraryId: 'library-a'));
    await service.updateSnapshot(_snapshot(libraryId: 'library-b'));
    await pumpEventQueue();
    lateArtwork.complete(Uri.file('/tmp/old-cover.png'));
    await pumpEventQueue();

    final artworkPaths = calls
        .where((call) => call.method == 'updateArtwork')
        .map((call) => (call.arguments as Map)['artworkPath'])
        .toList();
    expect(artworkPaths, <String>['/tmp/new-cover.png']);

    for (final payload in <Map<String, Object>>[
      <String, Object>{'type': 'play'},
      <String, Object>{'type': 'pause'},
      <String, Object>{'type': 'next'},
      <String, Object>{'type': 'previous'},
      <String, Object>{'type': 'stop'},
      <String, Object>{'type': 'seek', 'positionMicroseconds': 75000000},
    ]) {
      await _sendNativeCall(payload);
    }
    expect(commands.actions, <Object>[
      'play',
      'pause',
      'next',
      'previous',
      'stop',
      const Duration(seconds: 75),
    ]);

    await service.dispose();
  });
}

Future<void> _sendNativeCall(Map<String, Object> payload) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final message = _codec.encodeMethodCall(MethodCall('onControl', payload));
  await messenger.handlePlatformMessage(_channel.name, message, (_) {});
}

PlaybackSnapshot _snapshot({
  String? libraryId,
  String? songId = 'song-1',
  String? entryId = 'entry-1',
  String? artworkReference = 'https://example.invalid/cover.jpg?token=secret',
}) => PlaybackSnapshot(
  libraryId: libraryId,
  songId: songId,
  entryId: entryId,
  title: 'Echo Song',
  artist: 'Echo Artist',
  album: 'Echo Album',
  artworkReference: artworkReference,
  position: const Duration(seconds: 20),
  duration: const Duration(minutes: 3),
  isPlaying: false,
  playbackRequested: false,
  isStopped: false,
  isLoading: false,
  hasError: false,
  canPlay: true,
  canPause: false,
  canGoNext: true,
  canGoPrevious: true,
  canSeek: true,
  volume: 1,
  isMuted: false,
  loopMode: LoopMode.off,
  shuffleEnabled: false,
);

class _RecordingPlaybackCommands extends Fake implements PlaybackCommands {
  final List<Object> actions = <Object>[];

  @override
  Future<void> play() async => actions.add('play');

  @override
  Future<void> pause() async => actions.add('pause');

  @override
  Future<void> next() async => actions.add('next');

  @override
  Future<void> previous() async => actions.add('previous');

  @override
  Future<void> stop() async => actions.add('stop');

  @override
  Future<void> seek(Duration position) async => actions.add(position);
}
