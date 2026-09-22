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
}
