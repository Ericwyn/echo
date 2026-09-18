import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Bounded, serialized diagnostic writes. Playback never waits on disk I/O.
class PlaybackLogStore {
  PlaybackLogStore(
    this.directory, {
    DateTime Function()? now,
    this.maxFileBytes = 1024 * 1024,
    this.keepDays = 7,
  }) : _now = now ?? DateTime.now;
  final Directory directory;
  final DateTime Function() _now;
  final int maxFileBytes;
  final int keepDays;
  final List<String> _pending = [];
  Timer? _timer;
  Future<void> _writes = Future<void>.value();

  static Future<PlaybackLogStore> open() async {
    final root = await getApplicationSupportDirectory();
    final store = PlaybackLogStore(Directory('${root.path}/playback_logs'));
    await store.directory.create(recursive: true);
    return store;
  }

  void append(String line) {
    if (_pending.length >= 200) _pending.removeAt(0);
    _pending.add(line.length > 2048 ? line.substring(0, 2048) : line);
    _timer ??= Timer(const Duration(milliseconds: 250), () {
      unawaited(flush());
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return _writes;
    final batch = '${_pending.join('\n')}\n';
    _pending.clear();
    final day = _now().toIso8601String().substring(0, 10);
    _writes = _writes
        .then((_) async {
          await directory.create(recursive: true);
          final file = File('${directory.path}/$day.log');
          // Retain the most recent portion of a busy day, with a fixed disk bound.
          if (await file.exists() && await file.length() >= maxFileBytes) {
            final previous = File('${directory.path}/$day.previous.log');
            if (await previous.exists()) await previous.delete();
            await file.rename(previous.path);
          }
          await file.writeAsString(batch, mode: FileMode.append, flush: true);
          final oldest = _now()
              .subtract(Duration(days: keepDays - 1))
              .toIso8601String()
              .substring(0, 10);
          await for (final entry in directory.list()) {
            if (entry is! File) continue;
            final name = entry.uri.pathSegments.last;
            if (RegExp(
                  r'^\d{4}-\d{2}-\d{2}(\.previous)?\.log$',
                ).hasMatch(name) &&
                name.substring(0, 10).compareTo(oldest) < 0) {
              await entry.delete();
            }
          }
        })
        .catchError((Object _) {
          // Storage failure must neither break playback nor recursively log.
        });
    return _writes;
  }

  Future<String> read() async {
    await flush();
    try {
      final files = await directory
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();
      files.sort((a, b) {
        final nameA = a.uri.pathSegments.last;
        final nameB = b.uri.pathSegments.last;
        final day = nameA.substring(0, 10).compareTo(nameB.substring(0, 10));
        return day != 0 ? day : (nameA.contains('.previous') ? -1 : 1);
      });
      final parts = <String>[];
      for (final file in files) {
        parts.add(await file.readAsString());
      }
      return parts.join();
    } on Exception {
      return '';
    }
  }
}
