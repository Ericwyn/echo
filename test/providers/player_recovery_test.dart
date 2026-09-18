import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echoes/core/network/address_pool.dart';
import 'package:echoes/core/services/audio_cache_service.dart';
import 'package:echoes/core/services/download_service.dart';
import 'package:echoes/data/models/audio_quality.dart';
import 'package:echoes/data/models/server_address.dart';
import 'package:echoes/data/repositories/music_repository.dart';
import 'package:echoes/data/sources/subsonic_api_client.dart';
import 'package:echoes/providers/audio_cache_provider.dart';
import 'package:echoes/providers/audio_quality_provider.dart';
import 'package:echoes/providers/auth_provider.dart';
import 'package:echoes/providers/download_provider.dart';
import 'package:echoes/providers/music_provider.dart';
import 'package:echoes/core/network/connectivity_monitor.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/providers/api_provider.dart';
import 'package:echoes/providers/crossfade_provider.dart';
import 'package:echoes/providers/player_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlayer extends Mock implements audio.AudioPlayer {}

class MockConnectivity extends Mock implements ConnectivityMonitor {}

class MockCache extends Mock implements AudioCacheService {}

class MockDownloads extends Mock implements DownloadService {}

class MockApi extends Mock implements SubsonicApiClient {}

class MockPool extends Mock implements AddressPool {}

class MockMusic extends Mock implements MusicRepository {}

class TestAuth extends StateNotifier<AuthState> implements AuthNotifier {
  TestAuth() : super(AuthState(isInitializing: false));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockPlayer engine;
  late ProviderContainer container;
  late PlayerNotifier notifier;
  late StreamController<audio.PlaybackEvent> errors;
  late StreamController<audio.PlayerState> states;
  late StreamController<bool> playingEvents;
  late bool playing;
  late audio.ProcessingState processing;
  late Duration position;
  late audio.AudioSource? source;
  late int loads;
  late int plays;
  Completer<Duration?>? pendingLoad;
  final song = Song(
    id: 'preview',
    title: 'Preview',
    duration: 120,
    isPreview: true,
    previewStreamUrl: 'https://example.invalid/audio.mp3',
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(AudioQualityLevel.standard);
    registerFallbackValue(audio.LoopMode.off);
    registerFallbackValue(
      audio.AudioSource.uri(Uri.parse('https://example.invalid')),
    );
  });

  void createFixture({DateTime Function()? clock}) {
    SharedPreferences.setMockInitialValues({});
    engine = MockPlayer();
    final network = MockConnectivity();
    when(() => network.currentNetworkType).thenReturn(NetworkType.wifi);
    when(
      () => network.networkTypeStream,
    ).thenAnswer((_) => const Stream.empty());
    errors = StreamController<audio.PlaybackEvent>.broadcast(sync: true);
    states = StreamController<audio.PlayerState>.broadcast(sync: true);
    playingEvents = StreamController<bool>.broadcast(sync: true);
    playing = false;
    processing = audio.ProcessingState.ready;
    position = Duration.zero;
    source = null;
    loads = 0;
    plays = 0;
    pendingLoad = null;
    when(() => engine.playbackEventStream).thenAnswer((_) => errors.stream);
    when(() => engine.playerStateStream).thenAnswer((_) => states.stream);
    when(() => engine.playingStream).thenAnswer((_) => playingEvents.stream);
    when(() => engine.positionStream).thenAnswer((_) => const Stream.empty());
    when(
      () => engine.bufferedPositionStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => engine.durationStream).thenAnswer((_) => const Stream.empty());
    when(
      () => engine.shuffleModeEnabledStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => engine.playing).thenAnswer((_) => playing);
    when(() => engine.processingState).thenAnswer((_) => processing);
    when(() => engine.position).thenAnswer((_) => position);
    when(() => engine.bufferedPosition).thenReturn(const Duration(seconds: 30));
    when(() => engine.duration).thenReturn(const Duration(seconds: 120));
    when(() => engine.audioSource).thenAnswer((_) => source);
    when(() => engine.setUrl(any(), headers: any(named: 'headers'))).thenAnswer(
      (call) async {
        loads++;
        source = audio.AudioSource.uri(
          Uri.parse(call.positionalArguments.first as String),
        );
        position = Duration.zero;
        return pendingLoad == null
            ? const Duration(seconds: 120)
            : pendingLoad!.future;
      },
    );
    when(() => engine.play()).thenAnswer((_) async {
      playing = true;
      plays++;
    });
    when(() => engine.pause()).thenAnswer((_) async {
      playing = false;
    });
    when(() => engine.stop()).thenAnswer((_) async {
      playing = false;
    });
    when(() => engine.dispose()).thenAnswer((_) async {});
    when(() => engine.setVolume(any())).thenAnswer((_) async {});
    when(() => engine.setLoopMode(any())).thenAnswer((_) async {});
    when(() => engine.setShuffleModeEnabled(any())).thenAnswer((_) async {});
    when(() => engine.seek(any())).thenAnswer((call) async {
      position = call.positionalArguments.first as Duration;
    });
    final cache = MockCache();
    final downloads = MockDownloads();
    final api = MockApi();
    final pool = MockPool();
    final music = MockMusic();
    const route = ServerAddress(
      id: 'route',
      libraryId: 'library',
      label: 'Test',
      url: 'https://example.invalid',
      priority: 0,
      status: ServerAddressStatus.ok,
    );
    when(() => pool.activeAddress).thenReturn(route);
    when(() => pool.probeAll()).thenAnswer((_) async => route);
    when(() => api.dio).thenReturn(Dio(BaseOptions(baseUrl: route.url)));
    when(
      () => api.getStreamUrl(
        any(),
        maxBitRate: any(named: 'maxBitRate'),
        format: any(named: 'format'),
        timeOffset: any(named: 'timeOffset'),
      ),
    ).thenAnswer(
      (call) =>
          'https://example.invalid/audio?timeOffset=${call.namedArguments[#timeOffset] ?? 0}',
    );
    when(
      () => api.post(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => {});
    when(() => music.getSong(any())).thenAnswer((_) async => null);
    when(
      () => downloads.getDownloadedPath(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => cache.getCachedPath(
        songId: any(named: 'songId'),
        libraryId: any(named: 'libraryId'),
        quality: any(named: 'quality'),
      ),
    ).thenAnswer((_) async => null);
    container = ProviderContainer(
      overrides: [
        audioCacheServiceProvider.overrideWithValue(cache),
        downloadServiceProvider.overrideWithValue(downloads),
        subsonicApiClientProvider.overrideWithValue(api),
        addressPoolProvider.overrideWithValue(pool),
        musicRepositoryProvider.overrideWithValue(music),
        authStateProvider.overrideWith((_) => TestAuth()),
        effectiveQualityProvider.overrideWithValue(AudioQualityLevel.standard),
        connectivityMonitorProvider.overrideWithValue(network),
        playerProvider.overrideWith(
          (ref) => PlayerNotifier(
            ref,
            player: engine,
            restoreSession: false,
            clock: clock,
          ),
        ),
      ],
    );
    notifier = container.read(playerProvider.notifier);
  }

  tearDown(() async {
    await playingEvents.close();
    await errors.close();
    await states.close();
  });

  void playbackTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        container.dispose();
        await tester.pump();
      }
    });
  }

  playbackTest(
    'stream failure retries on unchanged Wi-Fi and restores position',
    (tester) async {
      createFixture();
      await notifier.initialized;
      final initial = notifier.playSong(song);
      await tester.pump();
      await initial;
      position = const Duration(seconds: 12);
      errors.addError(audio.PlayerException(0, 'connection lost'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(loads, 2);
      expect(position, const Duration(seconds: 12));
      expect(playing, isTrue);
    },
  );

  playbackTest('runtime failures have a bounded retry budget', (tester) async {
    createFixture();
    await notifier.initialized;
    final initial = notifier.playSong(song);
    await tester.pump();
    await initial;
    for (var attempt = 0; attempt < 5; attempt++) {
      errors.addError(audio.PlayerException(0, 'connection lost'));
      await tester.pump(Duration(seconds: 2 << attempt));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(loads, 5); // initial load plus four recoveries
    expect(playing, isFalse);
  });

  playbackTest('buffering watchdog retries after thirty seconds', (
    tester,
  ) async {
    createFixture(clock: () => tester.binding.clock.now());
    await notifier.initialized;
    final initial = notifier.playSong(song);
    await tester.pump();
    await initial;
    processing = audio.ProcessingState.buffering;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 31));
    processing = audio.ProcessingState.ready;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(loads, 2);
  });

  playbackTest(
    'failed transcoded seek reload restores the prior source and position',
    (tester) async {
      createFixture();
      await notifier.initialized;
      final regular = Song(
        id: 'normal',
        title: 'Normal',
        suffix: 'mp3',
        bitRate: 320,
        duration: 120,
      );
      final initial = notifier.playSong(regular);
      await tester.pump();
      await initial;
      position = const Duration(seconds: 12);
      final original = source;
      when(
        () => engine.setUrl(
          any(),
          initialPosition: any(named: 'initialPosition'),
        ),
      ).thenAnswer((_) async {
        source = audio.AudioSource.uri(
          Uri.parse('https://example.invalid/failed'),
        );
        throw audio.PlayerException(0, 'seek load failed');
      });
      when(
        () => engine.setAudioSource(
          any(),
          initialPosition: any(named: 'initialPosition'),
        ),
      ).thenAnswer((call) async {
        source = call.positionalArguments.first as audio.AudioSource;
        position = call.namedArguments[#initialPosition] as Duration;
        return const Duration(seconds: 120);
      });
      final seek = notifier.seek(const Duration(seconds: 60));
      await tester.pump();
      await seek;
      expect(source, same(original));
      expect(position, const Duration(seconds: 12));
      expect(
        container.read(playerProvider).position,
        const Duration(seconds: 12),
      );
      expect(playing, isTrue);
    },
  );

  playbackTest(
    'a failed recovery seek is not erased by a stale load-ready path',
    (tester) async {
      createFixture();
      await notifier.initialized;
      final initial = notifier.playSong(song);
      await tester.pump();
      await initial;
      position = const Duration(seconds: 12);
      when(
        () => engine.seek(any()),
      ).thenThrow(audio.PlayerException(0, 'seek failed'));
      errors.addError(audio.PlayerException(0, 'connection lost'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(loads, 2);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(loads, 3);
      expect(plays, 1);
    },
  );

  playbackTest('pause cancels a pending recovery', (tester) async {
    createFixture();
    await notifier.initialized;
    final initial = notifier.playSong(song);
    await tester.pump();
    await initial;
    errors.addError(audio.PlayerException(0, 'connection lost'));
    await notifier.pause();
    await tester.pump(const Duration(seconds: 20));
    expect(loads, 1);
    expect(playing, isFalse);
  });

  playbackTest('pause while loading is respected when the load completes', (
    tester,
  ) async {
    createFixture();
    await notifier.initialized;
    pendingLoad = Completer<Duration?>();
    final load = notifier.playSong(song);
    await tester.pump();
    await notifier.pause();
    pendingLoad!.complete(const Duration(seconds: 120));
    await load;
    expect(plays, 0);
    expect(playing, isFalse);
  });

  playbackTest(
    'old completion while replacing a source does not skip the new song',
    (tester) async {
      createFixture();
      await notifier.initialized;
      final initial = notifier.playSong(song);
      await tester.pump();
      await initial;
      final next = song.copyWith(
        id: 'next',
        previewStreamUrl: 'https://example.invalid/next.mp3',
      );
      pendingLoad = Completer<Duration?>();
      final load = notifier.playSong(next, queue: [song, next], index: 1);
      await tester.pump();
      states.add(audio.PlayerState(true, audio.ProcessingState.completed));
      await tester.pump();
      expect(loads, 2);
      expect(container.read(playerProvider).currentSong?.id, 'next');
      pendingLoad!.complete(const Duration(seconds: 120));
      await load;
    },
  );

  playbackTest(
    'repeat one reloads the full source instead of looping a decoder tail',
    (tester) async {
      createFixture();
      await notifier.initialized;
      final initial = notifier.playSong(song);
      await tester.pump();
      await initial;
      await notifier.setPlaybackMode(PlaybackMode.repeatOne, persist: false);
      states.add(audio.PlayerState(true, audio.ProcessingState.completed));
      await tester.pump();
      expect(loads, 2);
      verifyNever(() => engine.setLoopMode(audio.LoopMode.one));
      expect(container.read(playerProvider).currentSong?.id, song.id);
    },
  );

  playbackTest('system-style resume after app fade-out restores full volume', (
    tester,
  ) async {
    createFixture();
    await notifier.initialized;
    final initial = notifier.playSong(song);
    await tester.pump();
    await initial;
    await container
        .read(crossfadeDurationMsProvider.notifier)
        .setDuration(1000);
    playingEvents.add(true);
    final pause = notifier.pause();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await pause;
    clearInteractions(engine);
    await notifier.play();
    verify(() => engine.setVolume(1.0)).called(1);
    expect(playing, isTrue);
  });
}
