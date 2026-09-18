import 'package:flutter/widgets.dart';

import '../utils/toast_notifier.dart';

/// A diagnostic hint, not a claim that a battery restriction caused the delay.
class BackgroundPlaybackAdvisor {
  BackgroundPlaybackAdvisor({required this.notify});

  static final instance = BackgroundPlaybackAdvisor(
    notify: () => ToastNotifier.show('检测到后台播放处理延迟，可到“设置 → 后台播放”检查电池限制。'),
  );

  final VoidCallback notify;
  bool _pending = false;
  bool _shown = false;
  bool _foreground = true;

  void onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _flush();
  }

  void recordGap({required Duration gap, required bool wasBackground}) {
    if (_shown || !wasBackground || gap < const Duration(seconds: 5)) return;
    _pending = true;
    _flush();
  }

  void _flush() {
    if (!_foreground || !_pending || _shown) return;
    _pending = false;
    _shown = true;
    notify();
  }
}
