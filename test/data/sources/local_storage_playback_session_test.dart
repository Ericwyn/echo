import 'dart:convert';

import 'package:echoes/data/sources/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('invalid v2 playback session falls back to legacy v1', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'playback_session_v2': '{invalid',
      'playback_session_v1': jsonEncode(<String, dynamic>{
        'version': 1,
        'queue': <Object>[],
      }),
    });

    final session = await LocalStorage.getPlaybackSession();

    expect(session?['version'], 1);
  });

  test('saving v2 succeeds before removing the legacy snapshot', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'playback_session_v1': jsonEncode(<String, dynamic>{'version': 1}),
    });

    await LocalStorage.savePlaybackSession(<String, dynamic>{'version': 2});

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('playback_session_v2'), isTrue);
    expect(preferences.containsKey('playback_session_v1'), isFalse);
    expect((await LocalStorage.getPlaybackSession())?['version'], 2);
  });

  test('clearing a playback session removes both schema versions', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'playback_session_v1': '{}',
      'playback_session_v2': '{}',
    });

    await LocalStorage.clearPlaybackSession();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('playback_session_v1'), isFalse);
    expect(preferences.containsKey('playback_session_v2'), isFalse);
  });

  test('playback sessions are isolated by library', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await LocalStorage.savePlaybackSession(<String, dynamic>{
      'version': 2,
      'libraryId': 'library-a',
    }, libraryId: 'library-a');
    await LocalStorage.savePlaybackSession(<String, dynamic>{
      'version': 2,
      'libraryId': 'library-b',
    }, libraryId: 'library-b');

    expect(
      (await LocalStorage.getPlaybackSession(
        libraryId: 'library-a',
      ))?['libraryId'],
      'library-a',
    );
    expect(
      (await LocalStorage.getPlaybackSession(
        libraryId: 'library-b',
      ))?['libraryId'],
      'library-b',
    );
    expect(await LocalStorage.getPlaybackSession(), isNull);

    await LocalStorage.clearPlaybackSession(libraryId: 'library-a');
    expect(
      await LocalStorage.getPlaybackSession(libraryId: 'library-a'),
      isNull,
    );
    expect(
      (await LocalStorage.getPlaybackSession(
        libraryId: 'library-b',
      ))?['libraryId'],
      'library-b',
    );
  });

  test('legacy global session migrates only to its owning library', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'playback_session_v2': jsonEncode(<String, dynamic>{
        'version': 2,
        'libraryId': 'library-a',
      }),
    });

    expect(
      await LocalStorage.getPlaybackSession(libraryId: 'library-b'),
      isNull,
    );
    final migrated = await LocalStorage.getPlaybackSession(
      libraryId: 'library-a',
    );
    expect(migrated?['libraryId'], 'library-a');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('playback_session_v2'), isFalse);
  });
}
