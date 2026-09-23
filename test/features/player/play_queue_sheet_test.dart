import 'package:echoes/core/design/echo_design.dart';
import 'package:echoes/core/theme/app_theme.dart';
import 'package:echoes/data/models/song.dart';
import 'package:echoes/features/player/widgets/play_queue_sheet.dart';
import 'package:echoes/providers/player_provider.dart';
import 'package:echoes/widgets/cover_art_image.dart';
import 'package:echoes/widgets/song_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final songs = <Song>[
    Song(id: 'a', title: 'Current song', artist: 'First artist'),
    Song(
      id: 'b',
      title: 'A long queued song title that may wrap at large text sizes',
      artist: 'Second artist with a long display name',
      isPreview: true,
      previewCoverUrl: 'https://images.example.test/preview.jpg',
    ),
  ];

  Widget buildSubject({
    required PlayerState state,
    required Future<void> Function(int) onSelect,
    required Future<void> Function() onClear,
    required QueueSongAction onOpenSongActions,
    double textScale = 1,
    EchoMediaVisuals? mediaVisuals,
    Color? albumColor,
    void Function(int, int)? onReorder,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          );
        },
        home: Scaffold(
          body: SizedBox.expand(
            child: PlayQueueSheetView(
              playerState: state,
              mediaVisuals: mediaVisuals,
              albumColor: albumColor,
              onSelect: onSelect,
              onClear: onClear,
              onOpenSongActions: onOpenSongActions,
              onReorder: onReorder,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('queue rows remain operable at 200% text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final selected = <int>[];
    var cleared = 0;
    final opened = <int>[];
    await tester.pumpWidget(
      buildSubject(
        state: PlayerState(
          currentSong: songs.first,
          queue: songs,
          currentIndex: 0,
        ),
        textScale: 2,
        onSelect: (index) async => selected.add(index),
        onClear: () async => cleared += 1,
        onOpenSongActions: (context, index, song, entryId) async =>
            opened.add(index),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('关闭播放队列'), findsOneWidget);
    expect(find.byType(EchoSongRow), findsNWidgets(2));
    expect(find.byType(CoverArtImage), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('当前已暂停')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('试听')), findsOneWidget);
    expect(find.byIcon(AppIcons.play), findsOneWidget);
    expect(find.text('2'), findsNothing);
    final covers = tester.widgetList<CoverArtImage>(find.byType(CoverArtImage));
    expect(covers.last.coverArtId, 'https://images.example.test/preview.jpg');
    expect(find.bySemanticsLabel(RegExp('更多操作')), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(EchoDivider),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ReorderableListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text(songs[1].title));
    await tester.pump();
    expect(selected, <int>[1]);
    expect(opened, isEmpty);

    final secondMore = find.bySemanticsLabel('${songs[1].title}，更多操作');
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -160));
    await tester.pump();
    final moreSize = tester.getSize(secondMore);
    expect(moreSize.width, greaterThanOrEqualTo(48));
    expect(moreSize.height, greaterThanOrEqualTo(48));
    await tester.tap(secondMore);
    await tester.pump();
    expect(selected, <int>[1]);
    expect(opened, <int>[1]);

    final clearQueue = find.bySemanticsLabel(RegExp('清空后续播放队列'));
    await tester.tap(clearQueue);
    await tester.pump();
    expect(cleared, 1);
  });

  testWidgets('queue exposes whole-row drag affordances and position styling', (
    tester,
  ) async {
    final moves = <(int, int)>[];
    await tester.pumpWidget(
      buildSubject(
        state: PlayerState(
          currentSong: songs.last,
          queue: songs,
          currentIndex: 1,
          isPlaying: true,
        ),
        onSelect: (_) async {},
        onClear: () async {},
        onReorder: (oldIndex, newIndex) => moves.add((oldIndex, newIndex)),
        onOpenSongActions: (context, index, song, entryId) async {},
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('调整播放顺序')), findsNWidgets(2));
    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(2));
    expect(find.byIcon(AppIcons.dragHandle), findsNothing);
    final rows = tester
        .widgetList<EchoSongRow>(find.byType(EchoSongRow))
        .toList();
    expect(rows.first.isDimmed, isTrue);
    expect(rows.last.isCurrent, isTrue);
    expect(find.bySemanticsLabel(RegExp('正在播放')), findsOneWidget);
    expect(find.text('共 2 首 · 当前第 2 首 · 后续 0 首'), findsOneWidget);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.proxyDecorator, isNotNull);
    list.onReorder(0, 2);
    expect(moves, <(int, int)>[(0, 2)]);
  });

  testWidgets('desktop queue separates row selection from playback', (
    tester,
  ) async {
    final state = PlayerState(
      currentSong: songs.first,
      queue: songs,
      currentIndex: 0,
    );
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final selected = <String>[];
    final played = <String>[];
    final deleted = <String>[];
    String? selectedEntryId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: PlaybackQueueContent(
              scrollController: scrollController,
              playerState: state,
              desktopInteraction: true,
              onEntrySelected: (entryId) {
                if (entryId != null) selected.add(entryId);
                setState(() => selectedEntryId = entryId);
              },
              selectedEntryId: selectedEntryId,
              onDeleteEntry: deleted.add,
              onSelect: (index) async => played.add(state.queueEntryIds[index]),
              onReorder: (_, _) {},
              onOpenSongActions: (context, index, song, entryId) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    await tester.tap(find.text(songs[1].title));
    await tester.pump();
    expect(selected, <String>[state.queueEntryIds[1]]);
    expect(played, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(played, <String>[state.queueEntryIds[1]]);

    await tester.tap(find.bySemanticsLabel('播放 ${songs[1].title}'));
    await tester.pump();
    expect(played, <String>[state.queueEntryIds[1], state.queueEntryIds[1]]);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(deleted, <String>[state.queueEntryIds[1]]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('songs before the current one fade both lines of text', (
    tester,
  ) async {
    final queue = <Song>[
      Song(
        id: 'past',
        title: 'Past song',
        artist: 'Past artist',
        duration: 180,
      ),
      Song(
        id: 'current',
        title: 'Playing song',
        artist: 'Playing artist',
        duration: 200,
      ),
      Song(
        id: 'next',
        title: 'Next song',
        artist: 'Next artist',
        duration: 220,
      ),
    ];
    final visuals = EchoMediaVisuals.fallback();
    await tester.pumpWidget(
      buildSubject(
        state: PlayerState(
          currentSong: queue[1],
          queue: queue,
          currentIndex: 1,
          isPlaying: true,
        ),
        mediaVisuals: visuals,
        onSelect: (_) async {},
        onClear: () async {},
        onOpenSongActions: (context, index, song, entryId) async {},
      ),
    );
    await tester.pumpAndSettle();

    Color textColor(String text) =>
        tester.widget<Text>(find.text(text)).style!.color!;
    final pastTitle = textColor('Past song');
    final pastMetadata = textColor('Past artist · 03:00');
    final nextTitle = textColor('Next song');
    final nextMetadata = textColor('Next artist · 03:40');
    final surface = visuals.panelSurface;

    expect(pastTitle, pastMetadata);
    expect(
      EchoColors.contrastRatio(pastTitle, surface),
      lessThan(EchoColors.contrastRatio(nextTitle, surface)),
    );
    expect(
      EchoColors.contrastRatio(pastMetadata, surface),
      lessThan(EchoColors.contrastRatio(nextMetadata, surface)),
    );
    expect(
      EchoColors.contrastRatio(pastMetadata, surface),
      greaterThanOrEqualTo(3.49),
    );
  });

  testWidgets(
    'queue artwork aligns with its heading and current row has space',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildSubject(
          state: PlayerState(
            currentSong: songs.first,
            queue: songs,
            currentIndex: 0,
            isPlaying: true,
          ),
          onSelect: (_) async {},
          onClear: () async {},
          onOpenSongActions: (context, index, song, entryId) async {},
          onReorder: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();

      final headingLeft = tester.getTopLeft(find.text('播放队列')).dx;
      final artwork = find.byType(CoverArtImage).first;
      expect(tester.getTopLeft(artwork).dx, closeTo(headingLeft, 0.1));
      expect(
        tester.getSize(find.byType(EchoSongRow).first).height,
        greaterThan(tester.getSize(artwork).height + 16),
      );
    },
  );

  testWidgets(
    'long-pressing a song drags it while the more button opens actions',
    (tester) async {
      final moves = <(int, int)>[];
      final opened = <int>[];
      final selected = <int>[];
      await tester.pumpWidget(
        buildSubject(
          state: PlayerState(
            currentSong: songs.first,
            queue: songs,
            currentIndex: 0,
          ),
          onSelect: (index) async => selected.add(index),
          onClear: () async {},
          onReorder: (oldIndex, newIndex) => moves.add((oldIndex, newIndex)),
          onOpenSongActions: (context, index, song, entryId) async =>
              opened.add(index),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(songs.first.title));
      await tester.pump();
      expect(selected, <int>[0]);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text(songs.first.title)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moves, <(int, int)>[(0, 2)]);
      expect(opened, isEmpty);

      await tester.tap(find.bySemanticsLabel('${songs.first.title}，更多操作'));
      await tester.pump();
      expect(opened, <int>[0]);
    },
  );

  testWidgets('queue content consumes the panel media color scope', (
    tester,
  ) async {
    final visuals = EchoMediaVisuals.fallback(seed: const Color(0xFFBFD7EA));
    await tester.pumpWidget(
      buildSubject(
        state: PlayerState(
          currentSong: songs.first,
          queue: songs,
          currentIndex: 0,
        ),
        mediaVisuals: visuals,
        albumColor: const Color(0xFF7B1E3A),
        onSelect: (_) async {},
        onClear: () async {},
        onOpenSongActions: (context, index, song, entryId) async {},
      ),
    );
    await tester.pump();

    final surface = tester.widget<EchoSurface>(find.byType(EchoSurface).first);
    final currentTitle = tester.widget<Text>(find.text(songs.first.title));
    expect(surface.color, visuals.panelSurface);
    expect(currentTitle.style?.color, visuals.controlAccent);
  });

  testWidgets('empty queue explains the state and disables clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        state: PlayerState(),
        onSelect: (_) async {},
        onClear: () async {},
        onOpenSongActions: (context, index, song, entryId) async {},
      ),
    );
    await tester.pump();

    expect(find.text('队列为空'), findsOneWidget);
    expect(find.text('清空后续队列'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
