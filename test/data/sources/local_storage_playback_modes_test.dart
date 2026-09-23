import 'package:echoes/data/sources/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'stores shuffle and repeat independently and mirrors legacy mode',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await LocalStorage.setPlaybackModes(
        loopMode: 'all',
        shuffleEnabled: true,
      );

      expect(await LocalStorage.getPlaybackModes(), (
        loopMode: 'all',
        shuffleEnabled: true,
      ));
      expect(await LocalStorage.getPlaybackMode(), 'shuffle');

      await LocalStorage.setPlaybackModes(
        loopMode: 'one',
        shuffleEnabled: false,
      );
      expect(await LocalStorage.getPlaybackModes(), (
        loopMode: 'one',
        shuffleEnabled: false,
      ));
      expect(await LocalStorage.getPlaybackMode(), 'repeatOne');
    },
  );

  test(
    'invalid independent settings fall back to legacy mode migration',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'playback_modes_v2': '{invalid',
        'playback_mode': 'repeatAll',
      });

      expect(await LocalStorage.getPlaybackModes(), isNull);
      expect(await LocalStorage.getPlaybackMode(), 'repeatAll');
    },
  );
}
