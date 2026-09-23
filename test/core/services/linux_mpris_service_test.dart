import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:echoes/core/services/linux_mpris_service.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:echoes/providers/player/player_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

const _busName = 'org.mpris.MediaPlayer2.echoes';
const _objectPath = '/org/mpris/MediaPlayer2';
const _playerInterface = 'org.mpris.MediaPlayer2.Player';
const _propertiesInterface = 'org.freedesktop.DBus.Properties';

void main() {
  test(
    'publishes MPRIS state and routes remote transport/seek commands',
    () async {
      final commands = _RecordingPlaybackCommands();
      final service = LinuxMprisService(commands: commands);
      final client = DBusClient.session();
      await service.updateSnapshot(_snapshot());
      await service.start();

      try {
        final initial = await _getPlayerProperties(client);
        expect(initial['PlaybackStatus']!.asString(), 'Paused');
        expect(initial['CanSeek']!.asBoolean(), isTrue);
        final metadata = initial['Metadata']!.asStringVariantDict();
        expect(metadata['xesam:title']!.asString(), 'Echo Song');
        expect(metadata['mpris:length']!.asInt64(), 180000000);
        expect(
          metadata['mpris:trackid']!.asObjectPath().value,
          startsWith('$_objectPath/Track/'),
        );

        await client.callMethod(
          destination: _busName,
          path: DBusObjectPath(_objectPath),
          interface: _playerInterface,
          name: 'Next',
          replySignature: DBusSignature(''),
        );
        expect(commands.nextCount, 1);

        await client.callMethod(
          destination: _busName,
          path: DBusObjectPath(_objectPath),
          interface: _playerInterface,
          name: 'Seek',
          values: <DBusValue>[const DBusInt64(15000000)],
          replySignature: DBusSignature(''),
        );
        expect(commands.seeks, <Duration>[const Duration(seconds: 35)]);

        await service.updateSnapshot(_snapshot(isPlaying: true));
        final playing = await _getPlayerProperties(client);
        expect(playing['PlaybackStatus']!.asString(), 'Playing');
      } finally {
        await client.close();
        await service.dispose();
      }
    },
  );

  test(
    'publishes only a resolved local artwork URI and clears stale art',
    () async {
      final commands = _RecordingPlaybackCommands();
      final service = LinuxMprisService(
        commands: commands,
        artworkResolver: (_) async => Uri.file('/tmp/echo-cover.png'),
      );
      final client = DBusClient.session();
      await service.updateSnapshot(_snapshot());
      await service.start();

      try {
        await pumpEventQueue();
        final withArtwork = await _getPlayerProperties(client);
        final metadata = withArtwork['Metadata']!.asStringVariantDict();
        expect(
          metadata['mpris:artUrl']!.asString(),
          'file:///tmp/echo-cover.png',
        );
        expect(
          metadata['mpris:artUrl']!.asString(),
          isNot(contains('example.invalid')),
        );

        await service.updateSnapshot(_snapshot(artworkReference: null));
        final withoutArtwork = await _getPlayerProperties(client);
        expect(
          withoutArtwork['Metadata']!.asStringVariantDict().containsKey(
            'mpris:artUrl',
          ),
          isFalse,
        );
      } finally {
        await client.close();
        await service.dispose();
      }
    },
  );

  test(
    'ignores artwork that arrives after the current track changed',
    () async {
      final commands = _RecordingPlaybackCommands();
      final lateArtwork = Completer<Uri?>();
      final service = LinuxMprisService(
        commands: commands,
        artworkResolver: (snapshot) => snapshot.songId == 'old-song'
            ? lateArtwork.future
            : Future<Uri?>.value(Uri.file('/tmp/current-cover.png')),
      );
      final client = DBusClient.session();
      await service.updateSnapshot(
        _snapshot(songId: 'old-song', entryId: 'old-entry'),
      );
      await service.start();

      try {
        await service.updateSnapshot(
          _snapshot(songId: 'new-song', entryId: 'new-entry'),
        );
        await pumpEventQueue();
        lateArtwork.complete(Uri.file('/tmp/old-cover.png'));
        await pumpEventQueue();

        final properties = await _getPlayerProperties(client);
        final metadata = properties['Metadata']!.asStringVariantDict();
        expect(
          metadata['mpris:artUrl']!.asString(),
          'file:///tmp/current-cover.png',
        );
      } finally {
        if (!lateArtwork.isCompleted) lateArtwork.complete(null);
        await client.close();
        await service.dispose();
      }
    },
  );
}

Future<Map<String, DBusValue>> _getPlayerProperties(DBusClient client) async {
  final result = await client.callMethod(
    destination: _busName,
    path: DBusObjectPath(_objectPath),
    interface: _propertiesInterface,
    name: 'GetAll',
    values: <DBusValue>[const DBusString(_playerInterface)],
    replySignature: DBusSignature('a{sv}'),
  );
  return result.returnValues.single.asStringVariantDict();
}

PlaybackSnapshot _snapshot({
  bool isPlaying = false,
  String? artworkReference = 'https://example.invalid/cover.jpg',
  String songId = 'song-1',
  String entryId = 'entry-1',
}) => PlaybackSnapshot(
  songId: songId,
  entryId: entryId,
  title: 'Echo Song',
  artist: 'Echo Artist',
  album: 'Echo Album',
  artworkReference: artworkReference,
  position: const Duration(seconds: 20),
  duration: const Duration(minutes: 3),
  isPlaying: isPlaying,
  playbackRequested: isPlaying,
  isStopped: false,
  isLoading: false,
  hasError: false,
  canPlay: true,
  canPause: isPlaying,
  canGoNext: true,
  canGoPrevious: true,
  canSeek: true,
  volume: 0.75,
  isMuted: false,
  loopMode: LoopMode.all,
  shuffleEnabled: false,
);

class _RecordingPlaybackCommands implements PlaybackCommands {
  int nextCount = 0;
  final List<Duration> seeks = <Duration>[];

  @override
  Future<void> next() async => nextCount++;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> setUserVolume(double volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> setPlaybackMode(
    PlaybackMode mode, {
    bool persist = true,
  }) async {}

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> skipToQueueEntry(String entryId) async {}

  @override
  void removeQueueEntry(String entryId) {}

  @override
  void reorderQueue(int oldIndex, int newIndex) {}
}
