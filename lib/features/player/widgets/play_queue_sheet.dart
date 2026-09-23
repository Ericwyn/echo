import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../data/models/song.dart';
import '../../../providers/palette_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/song_list_item.dart';
import 'song_options_sheet.dart';

Future<void> showPlayQueueSheet({
  required BuildContext context,
  bool useRootNavigator = true,
}) {
  return showEchoBottomSheet<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    builder: (_) => const PlayQueueSheet(),
  );
}

/// Playback queue bound to the production player provider.
class PlayQueueSheet extends ConsumerWidget {
  const PlayQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueSnapshot = ref.watch(
      playerProvider.select(
        (state) => (
          playbackQueue: state.playbackQueue,
          isPlaying: state.isPlaying,
          processingState: state.processingState,
          isSeeking: state.isSeeking,
          isChangingSource: state.isChangingSource,
          hasPlaybackError: state.hasPlaybackError,
          shuffleEnabled: state.shuffleEnabled,
          loopMode: state.loopMode,
        ),
      ),
    );
    final visuals = ref.watch(resolvedCurrentSongMediaVisualsProvider);
    final playerState = PlayerState(
      playbackQueue: queueSnapshot.playbackQueue,
      isPlaying: queueSnapshot.isPlaying,
      processingState: queueSnapshot.processingState,
      isSeeking: queueSnapshot.isSeeking,
      isChangingSource: queueSnapshot.isChangingSource,
      hasPlaybackError: queueSnapshot.hasPlaybackError,
      shuffleEnabled: queueSnapshot.shuffleEnabled,
      loopMode: queueSnapshot.loopMode,
    );

    return PlayQueueSheetView(
      playerState: playerState,
      mediaVisuals: visuals,
      onSelect: (index) async {
        final player = ref.read(playerProvider.notifier);
        final entryId = queueSnapshot.playbackQueue.entryIds[index];
        Navigator.of(context).pop();
        await Future<void>.delayed(Duration.zero);
        unawaited(player.skipToQueueEntry(entryId));
      },
      onClear: () async {
        await ref.read(playerProvider.notifier).clearQueue();
        if (context.mounted) Navigator.of(context).pop();
      },
      onReorder: ref.read(playerProvider.notifier).reorderQueue,
      onOpenSongActions: (rowContext, index, song) {
        return showSongOptionsSheet(
          context: rowContext,
          song: song,
          mediaVisuals: visuals,
          extraActions: <SongOptionsExtraAction>[
            SongOptionsExtraAction(
              icon: AppIcons.removeCircle,
              title: '从队列移除',
              isDestructive: true,
              onPressed: () {
                final entryId = queueSnapshot.playbackQueue.entryIds[index];
                ref.read(playerProvider.notifier).removeQueueEntry(entryId);
              },
            ),
          ],
        );
      },
    );
  }
}

typedef QueueSongAction =
    Future<void> Function(BuildContext context, int index, Song song);

/// Provider-free queue surface for deterministic gesture and a11y tests.
@visibleForTesting
class PlayQueueSheetView extends StatelessWidget {
  const PlayQueueSheetView({
    super.key,
    required this.playerState,
    required this.onSelect,
    required this.onClear,
    required this.onOpenSongActions,
    this.onReorder,
    this.mediaVisuals,
    this.albumColor,
  });

  final PlayerState playerState;
  final EchoMediaVisuals? mediaVisuals;

  /// Compatibility seed for provider-free tests and older call sites.
  final Color? albumColor;
  final Future<void> Function(int index) onSelect;
  final Future<void> Function() onClear;
  final QueueSongAction onOpenSongActions;
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final topRadius = BorderRadius.only(
      topLeft: context.echoRadii.scene.topLeft,
      topRight: context.echoRadii.scene.topRight,
    );
    final visuals =
        mediaVisuals ??
        EchoMediaVisuals.fallback(
          seed: albumColor ?? EchoColors.contentTintFallback,
        );

    return EchoMediaColorScope(
      visuals: visuals,
      role: EchoMediaSurfaceRole.panel,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Semantics(
            container: true,
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: '播放队列',
            child: EchoSurface(
              level: EchoSurfaceLevel.modal,
              color: context.echoColors.surface,
              borderRadius: topRadius,
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  children: <Widget>[
                    SizedBox(height: context.echoSpacing.xs),
                    Center(
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.echoColors.divider,
                            borderRadius: context.echoRadii.pill,
                          ),
                          child: const SizedBox(width: 36, height: 4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        context.echoSpacing.md,
                        context.echoSpacing.sm,
                        context.echoSpacing.xs,
                        context.echoSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Semantics(
                                  header: true,
                                  child: Text(
                                    '播放队列',
                                    style: context.echoTypography.headline,
                                  ),
                                ),
                                SizedBox(height: context.echoSpacing.xxs),
                                Text(
                                  currentIndex < 0
                                      ? '共 ${queue.length} 首'
                                      : '共 ${queue.length} 首 · 当前第 ${currentIndex + 1} 首 · 后续 ${queue.length - currentIndex - 1} 首',
                                  style: context.echoTypography.metadata,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: context.echoSpacing.sm),
                          EchoIconButton(
                            icon: AppIcons.close,
                            label: '关闭播放队列',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                    const EchoDivider(),
                    Expanded(
                      child: queue.isEmpty
                          ? const EchoEmptyState(
                              title: '队列为空',
                              description: '开始播放一首歌曲后，接下来的曲目会出现在这里。',
                              icon: AppIcons.queue,
                            )
                          : _PlayQueueList(
                              scrollController: scrollController,
                              playerState: playerState,
                              onSelect: onSelect,
                              onOpenSongActions: onOpenSongActions,
                              onReorder: onReorder,
                            ),
                    ),
                    const EchoDivider(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.echoSpacing.md,
                        context.echoSpacing.xs,
                        context.echoSpacing.md,
                        context.echoSpacing.sm,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: EchoButton.ghost(
                          label: '清空后续队列',
                          semanticLabel: '清空后续播放队列，保留当前曲目',
                          leadingIcon: AppIcons.clearAll,
                          onPressed: queue.isEmpty
                              ? null
                              : () => unawaited(onClear()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayQueueList extends StatefulWidget {
  const _PlayQueueList({
    required this.scrollController,
    required this.playerState,
    required this.onSelect,
    required this.onOpenSongActions,
    required this.onReorder,
  });

  final ScrollController scrollController;
  final PlayerState playerState;
  final Future<void> Function(int index) onSelect;
  final QueueSongAction onOpenSongActions;
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  State<_PlayQueueList> createState() => _PlayQueueListState();
}

class _PlayQueueListState extends State<_PlayQueueList> {
  final Map<String, GlobalKey> _entryKeys = <String, GlobalKey>{};
  bool _positionScheduled = false;
  int? _dragRevision;
  bool? _dragShuffleEnabled;

  @override
  Widget build(BuildContext context) {
    final state = widget.playerState;
    final activeIds = state.queueEntryIds.toSet();
    _entryKeys.removeWhere((id, _) => !activeIds.contains(id));
    _scheduleInitialPosition(context);

    return ReorderableListView.builder(
      scrollController: widget.scrollController,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = Curves.easeOut.transform(animation.value);
            final accent = context.echoColors.accent;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: context.echoRadii.control,
                border: Border.all(
                  color: accent.withValues(alpha: 0.65 + 0.35 * progress),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08 * progress),
                    blurRadius: 10 * progress,
                    spreadRadius: progress,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: child,
        );
      },
      padding: EdgeInsets.symmetric(vertical: context.echoSpacing.xs),
      itemCount: state.queue.length,
      onReorderStart: (_) {
        _dragRevision = widget.playerState.playbackQueue.revision;
        _dragShuffleEnabled = widget.playerState.shuffleEnabled;
      },
      onReorder: (oldIndex, newIndex) {
        final startedAt = _dragRevision;
        final startedWithShuffle = _dragShuffleEnabled;
        _dragRevision = null;
        _dragShuffleEnabled = null;
        if (startedAt != null &&
            (startedAt != widget.playerState.playbackQueue.revision ||
                startedWithShuffle != widget.playerState.shuffleEnabled)) {
          return;
        }
        widget.onReorder?.call(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final song = state.queue[index];
        final entryId = state.queueEntryIds[index];
        final isCurrent = index == state.currentIndex;
        final statusLabel = state.isLoading
            ? '正在加载'
            : state.isPlaying
            ? '正在播放'
            : '当前已暂停';
        final semanticsActions = <CustomSemanticsAction, VoidCallback>{};
        if (widget.onReorder != null && index > 0) {
          semanticsActions[const CustomSemanticsAction(label: '上移')] = () {
            widget.onReorder!(index, index - 1);
          };
        }
        if (widget.onReorder != null && index < state.queue.length - 1) {
          semanticsActions[const CustomSemanticsAction(label: '下移')] = () {
            widget.onReorder!(index, index + 2);
          };
        }

        return Padding(
          key: _entryKeys.putIfAbsent(entryId, GlobalKey.new),
          padding: EdgeInsets.only(bottom: context.echoSpacing.xxs),
          child: Semantics(
            label: widget.onReorder == null
                ? null
                : '长按并拖动 ${song.title}，调整播放顺序',
            customSemanticsActions: semanticsActions,
            child: ReorderableDelayedDragStartListener(
              index: index,
              enabled: widget.onReorder != null,
              child: EchoSongRow(
                index: index,
                song: song,
                variant: EchoSongRowVariant.standard,
                isCurrent: isCurrent,
                isDimmed: state.currentIndex >= 0 && index < state.currentIndex,
                currentStatusLabel: statusLabel,
                isCurrentLoading: state.isLoading,
                currentIndicatorIcon: state.isPlaying
                    ? AppIcons.pause
                    : AppIcons.play,
                contentPadding: EdgeInsetsDirectional.fromSTEB(
                  context.echoSpacing.md,
                  context.echoSpacing.xs,
                  context.echoSpacing.xs,
                  context.echoSpacing.xs,
                ),
                innerPadding: isCurrent
                    ? EdgeInsets.symmetric(vertical: context.echoSpacing.xxs)
                    : EdgeInsets.zero,
                onPressed: () => unawaited(widget.onSelect(index)),
                onMorePressed: () =>
                    unawaited(widget.onOpenSongActions(context, index, song)),
                moreSemanticLabel: '${song.title}，更多操作',
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleInitialPosition(BuildContext context) {
    final currentIndex = widget.playerState.currentIndex;
    if (_positionScheduled || currentIndex < 0) return;
    _positionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      final entryId = widget.playerState.currentEntryId;
      final targetContext = entryId == null
          ? null
          : _entryKeys[entryId]?.currentContext;
      if (targetContext != null) {
        unawaited(Scrollable.ensureVisible(targetContext, alignment: 0.35));
        return;
      }

      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final estimatedExtent = 76 + max(0.0, textScale - 1) * 48;
      final position = widget.scrollController.position;
      widget.scrollController.jumpTo(
        (currentIndex * estimatedExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = entryId == null
            ? null
            : _entryKeys[entryId]?.currentContext;
        if (context != null) {
          unawaited(Scrollable.ensureVisible(context, alignment: 0.35));
        }
      });
    });
  }
}
