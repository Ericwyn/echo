import 'package:echoes/core/services/status_notifier_host_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one watcher alias disappearing does not hide a live tray host', () {
    final tracker = StatusNotifierHostTracker();
    tracker.beginInitialLookup();
    tracker.applyInitialLookup('org.kde.StatusNotifierWatcher', hasOwner: true);
    tracker.applyInitialLookup(
      'org.freedesktop.StatusNotifierWatcher',
      hasOwner: true,
    );
    tracker.finishInitialLookup();

    expect(tracker.hasHost, isTrue);
    expect(
      tracker.applyOwnerChange(
        'org.kde.StatusNotifierWatcher',
        hasOwner: false,
      ),
      isTrue,
    );
    expect(tracker.hasHost, isTrue);
    tracker.applyOwnerChange(
      'org.freedesktop.StatusNotifierWatcher',
      hasOwner: false,
    );
    expect(tracker.hasHost, isFalse);
  });

  test('owner change wins over stale initial name-owner lookup', () {
    final tracker = StatusNotifierHostTracker();
    tracker.beginInitialLookup();

    tracker.applyOwnerChange('org.kde.StatusNotifierWatcher', hasOwner: true);
    tracker.applyInitialLookup(
      'org.kde.StatusNotifierWatcher',
      hasOwner: false,
    );
    tracker.applyInitialLookup(
      'org.freedesktop.StatusNotifierWatcher',
      hasOwner: false,
    );
    tracker.finishInitialLookup();

    expect(tracker.hasHost, isTrue);
  });

  test('unrelated D-Bus names do not affect host availability', () {
    final tracker = StatusNotifierHostTracker();

    expect(
      tracker.applyOwnerChange('org.example.OtherService', hasOwner: true),
      isFalse,
    );
    expect(tracker.hasHost, isFalse);
  });
}
