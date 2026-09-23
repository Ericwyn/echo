/// Tracks StatusNotifierWatcher names without treating the KDE and freedesktop
/// aliases as the same service. The host can expose either or both names.
class StatusNotifierHostTracker {
  static const List<String> watcherNames = <String>[
    'org.kde.StatusNotifierWatcher',
    'org.freedesktop.StatusNotifierWatcher',
  ];

  final Set<String> _availableWatchers = <String>{};
  final Set<String> _changedDuringInitialLookup = <String>{};
  bool _initialLookupInProgress = false;

  bool get hasHost => _availableWatchers.isNotEmpty;

  void beginInitialLookup() {
    _availableWatchers.clear();
    _changedDuringInitialLookup.clear();
    _initialLookupInProgress = true;
  }

  /// Applies a GetNameOwner result unless a newer owner-change event for this
  /// name arrived while the asynchronous lookup was in flight.
  void applyInitialLookup(String name, {required bool hasOwner}) {
    if (!_initialLookupInProgress ||
        !watcherNames.contains(name) ||
        _changedDuringInitialLookup.contains(name)) {
      return;
    }
    _setOwner(name, hasOwner: hasOwner);
  }

  void finishInitialLookup() {
    _initialLookupInProgress = false;
    _changedDuringInitialLookup.clear();
  }

  /// Returns false when [name] is not one of the supported watcher aliases.
  bool applyOwnerChange(String name, {required bool hasOwner}) {
    if (!watcherNames.contains(name)) return false;
    if (_initialLookupInProgress) _changedDuringInitialLookup.add(name);
    _setOwner(name, hasOwner: hasOwner);
    return true;
  }

  void clear() {
    _availableWatchers.clear();
    _changedDuringInitialLookup.clear();
    _initialLookupInProgress = false;
  }

  void _setOwner(String name, {required bool hasOwner}) {
    if (hasOwner) {
      _availableWatchers.add(name);
    } else {
      _availableWatchers.remove(name);
    }
  }
}
