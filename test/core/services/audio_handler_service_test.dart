import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:echoes/core/services/audio_handler_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer player;
  late EchoAudioHandler handler;

  setUp(() {
    player = _MockAudioPlayer();
    when(() => player.playingStream).thenAnswer((_) => const Stream.empty());
    when(() => player.positionStream).thenAnswer((_) => const Stream.empty());
    when(
      () => player.processingStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    when(() => player.position).thenReturn(const Duration(seconds: 2));
    when(() => player.bufferedPosition).thenReturn(const Duration(seconds: 3));
    when(() => player.speed).thenReturn(1.0);
    handler = EchoAudioHandler(player);
  });

  test('media session advertises seek support for notification progress', () {
    expect(echoPlaybackSystemActions, contains(MediaAction.seek));
  });

  test(
    'delegates media-session seeks to the player notifier callback',
    () async {
      Duration? received;
      handler.onSeek = (position) async {
        received = position;
      };

      await handler.seek(const Duration(seconds: 45));

      expect(received, const Duration(seconds: 45));
      verifyNever(() => player.seek(any()));
    },
  );

  test(
    'source replacement never publishes idle until the transition ends',
    () async {
      final events = StreamController<ProcessingState>();
      when(() => player.processingStateStream).thenAnswer((_) => events.stream);
      final transitioning = EchoAudioHandler(player);
      when(() => player.processingState).thenReturn(ProcessingState.idle);
      transitioning.beginSourceTransition(1, playing: true);
      events.add(ProcessingState.idle);
      await Future<void>.delayed(Duration.zero);
      expect(
        transitioning.playbackState.value.processingState,
        AudioProcessingState.loading,
      );
      expect(transitioning.playbackState.value.playing, isTrue);
      transitioning.beginSourceTransition(2, playing: true);
      transitioning.endSourceTransition(1);
      expect(
        transitioning.playbackState.value.processingState,
        AudioProcessingState.loading,
      );
      when(() => player.processingState).thenReturn(ProcessingState.ready);
      transitioning.endSourceTransition(2);
      expect(
        transitioning.playbackState.value.processingState,
        AudioProcessingState.ready,
      );
      await events.close();
    },
  );

  test('metadata updates do not turn paused playback into playing', () async {
    when(() => player.playing).thenReturn(false);
    await handler.updateMediaItem(const MediaItem(id: 'song', title: 'Song'));
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('system controls delegate to the same transport as the app', () async {
    final calls = <String>[];
    handler.onPlay = () async {
      calls.add('play');
    };
    handler.onPause = () async {
      calls.add('pause');
    };
    await handler.play();
    await handler.pause();
    expect(calls, ['play', 'pause']);
    verifyNever(() => player.play());
    verifyNever(() => player.pause());
  });

  test('adds the server timeOffset to media-session progress', () {
    handler.setPositionOffset(const Duration(seconds: 45));

    expect(
      handler.playbackState.value.updatePosition,
      const Duration(seconds: 47),
    );
    expect(
      handler.playbackState.value.bufferedPosition,
      const Duration(seconds: 48),
    );
  });
}
