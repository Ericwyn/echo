import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/local_storage.dart';

final dynamicPlayerBackgroundProvider =
    StateNotifierProvider<DynamicPlayerBackgroundNotifier, bool>(
      (ref) => DynamicPlayerBackgroundNotifier(),
    );

class DynamicPlayerBackgroundNotifier extends StateNotifier<bool> {
  late final Future<void> ready;
  bool _changedBeforeLoad = false;
  bool _loaded = false;

  DynamicPlayerBackgroundNotifier() : super(true) {
    ready = _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await LocalStorage.getDynamicPlayerBackground();
      if (mounted && !_changedBeforeLoad) state = enabled;
    } catch (_) {
      // Keep the default-on appearance if local preferences are unavailable.
    } finally {
      _loaded = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _changedBeforeLoad = true;
    if (_loaded && state == enabled) return;
    state = enabled;
    try {
      await LocalStorage.setDynamicPlayerBackground(enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
