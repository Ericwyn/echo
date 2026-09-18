import 'dart:io';
import 'package:echoes/core/utils/playback_log_store_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('echo-playback-log');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('playback diagnostics survive a new store instance', () async {
    final first = PlaybackLogStore(directory);
    first.append('session one: song completed');
    await first.flush();
    final second = PlaybackLogStore(directory);
    second.append('session two: app started');
    expect(await second.read(), contains('session one: song completed'));
    expect(await second.read(), contains('session two: app started'));
  });

  test('retains seven days and rotates a busy day', () async {
    var now = DateTime(2026, 9, 1);
    final store = PlaybackLogStore(directory, now: () => now, maxFileBytes: 20);
    store.append('old day');
    await store.flush();
    now = DateTime(2026, 9, 8);
    store.append('first long playback entry');
    await store.flush();
    store.append('second playback entry');
    await store.flush();
    expect(await store.read(), isNot(contains('old day')));
    expect(await store.read(), contains('first long playback entry'));
    expect(directory.listSync().length, 2);
  });

  test('concurrent flushes serialize without losing log records', () async {
    final store = PlaybackLogStore(directory);
    store.append('first');
    final first = store.flush();
    store.append('second');
    final second = store.flush();
    await Future.wait([first, second]);
    expect(await store.read(), 'first\nsecond\n');
  });
}
