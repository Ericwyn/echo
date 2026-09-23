import 'package:echoes/providers/player_appearance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists the dynamic player background preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dynamic_player_background_v1': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(dynamicPlayerBackgroundProvider.notifier);
    await notifier.ready;
    expect(container.read(dynamicPlayerBackgroundProvider), isFalse);

    await notifier.setEnabled(true);
    expect(container.read(dynamicPlayerBackgroundProvider), isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dynamic_player_background_v1'), isTrue);
  });
}
