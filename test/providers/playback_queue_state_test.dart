import 'dart:math';

import 'package:echoes/data/models/song.dart';
import 'package:echoes/providers/player/playback_queue_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var nextId = 0;
  String makeId() => 'entry-${nextId++}';
  Song song(String id) => Song(id: id, title: id);

  setUp(() => nextId = 0);

  test('duplicate songs retain independent queue identities', () {
    final queue = PlaybackQueueState.fromSongs(
      <Song>[song('A'), song('A')],
      currentIndex: 1,
      idFactory: makeId,
    );

    expect(queue.entryIds, <String>['entry-0', 'entry-1']);
    expect(queue.currentEntryId, 'entry-1');
    expect(queue.removeAt(0).currentEntryId, 'entry-1');
    expect(queue.removeAt(0).songs.single.id, 'A');
  });

  test('shuffle keeps prefix and current entry fixed', () {
    final queue = PlaybackQueueState.fromSongs(
      <Song>[for (final id in 'ABCDEFG'.split('')) song(id)],
      currentIndex: 2,
      idFactory: makeId,
    );

    final shuffled = queue.enableShuffle(Random(7));

    expect(shuffled.playOrder.take(3), queue.playOrder.take(3));
    expect(shuffled.playOrder.toSet(), queue.playOrder.toSet());
    expect(shuffled.currentEntryId, queue.currentEntryId);
  });

  test('restoring base order never revives a removed entry', () {
    final original = PlaybackQueueState.fromSongs(
      <Song>[for (final id in 'ABCDE'.split('')) song(id)],
      currentIndex: 1,
      idFactory: makeId,
    );
    final shuffled = original.enableShuffle(Random(2));
    final removedId = shuffled.playOrder.last;
    final restored = shuffled.removeEntry(removedId).restoreBaseOrder();

    expect(restored.playOrder, restored.baseOrder);
    expect(restored.entries, isNot(contains(removedId)));
    expect(restored.playOrder, isNot(contains(removedId)));
  });

  test('normal reorder updates base while shuffle reorder is temporary', () {
    final original = PlaybackQueueState.fromSongs(
      <Song>[song('A'), song('B'), song('C')],
      currentIndex: 0,
      idFactory: makeId,
    );
    final normalMove = original.move(2, 0, shuffleEnabled: false);
    expect(normalMove.playOrder, normalMove.baseOrder);
    expect(normalMove.songs.map((item) => item.id), <String>['C', 'A', 'B']);

    final shuffledMove = normalMove.move(2, 0, shuffleEnabled: true);
    expect(shuffledMove.playOrder, isNot(shuffledMove.baseOrder));
    expect(shuffledMove.restoreBaseOrder().playOrder, normalMove.baseOrder);
  });

  test('play next inserts after current in both orders', () {
    final queue = PlaybackQueueState.fromSongs(
      <Song>[song('A'), song('B'), song('C')],
      currentIndex: 1,
      idFactory: makeId,
    ).enableShuffle(Random(4));

    final updated = queue.insertNext(song('X'), idFactory: makeId);
    final playCurrent = updated.playOrder.indexOf(updated.currentEntryId!);
    final baseCurrent = updated.baseOrder.indexOf(updated.currentEntryId!);
    expect(updated.entries[updated.playOrder[playCurrent + 1]]!.song.id, 'X');
    expect(updated.entries[updated.baseOrder[baseCurrent + 1]]!.song.id, 'X');
  });

  test('clear upcoming preserves prefix and current in both orders', () {
    final queue = PlaybackQueueState.fromSongs(
      <Song>[song('A'), song('B'), song('C'), song('D')],
      currentIndex: 1,
      idFactory: makeId,
    );

    final cleared = queue.clearUpcoming();
    expect(cleared.songs.map((item) => item.id), <String>['A', 'B']);
    expect(cleared.baseOrder, cleared.playOrder);
    expect(cleared.currentSong?.id, 'B');
  });

  test('next shuffle round avoids repeating the boundary song', () {
    final queue = PlaybackQueueState.fromSongs(
      <Song>[song('A'), song('B'), song('C')],
      currentIndex: 2,
      idFactory: makeId,
    );

    final nextRound = queue.nextShuffleRound(Random(1));
    expect(nextRound.currentIndex, 0);
    expect(nextRound.currentSong?.id, isNot('C'));
    expect(nextRound.playOrder.toSet(), queue.playOrder.toSet());
  });

  test(
    'persisted queue repair filters references and keeps deletions deleted',
    () {
      final queue = PlaybackQueueState.fromSongs(
        <Song>[song('A'), song('A'), song('C')],
        currentIndex: 1,
        idFactory: makeId,
      );
      final json = queue.toJson();
      json['baseOrder'] = <String>['missing', queue.playOrder[1]];
      json['playOrder'] = <String>[
        queue.playOrder[2],
        queue.playOrder[2],
        'missing',
      ];

      final restored = PlaybackQueueState.fromJson(json)!;
      expect(restored.entries.length, 3);
      expect(restored.baseOrder.toSet(), queue.baseOrder.toSet());
      expect(restored.playOrder.toSet(), queue.playOrder.toSet());
      expect(restored.currentEntryId, queue.currentEntryId);
    },
  );
}
