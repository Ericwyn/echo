import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../data/models/song.dart';
import '../../../providers/palette_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/echo_artwork.dart';
import '../widgets/current_lyrics_panel.dart';
import '../widgets/player_backdrop.dart';
import '../widgets/play_queue_sheet.dart';
import '../widgets/song_options_sheet.dart';

enum DesktopPlayerPanel { lyrics, queue }

/// Desktop now-playing work area. The artwork stays in place while the right
/// pane changes between synchronized lyrics and the live playback queue.
class DesktopPlayerWorkspace extends ConsumerStatefulWidget {
  const DesktopPlayerWorkspace({
    super.key,
    required this.panel,
    required this.onPanelChanged,
    required this.onClose,
  });

  final DesktopPlayerPanel panel;
  final ValueChanged<DesktopPlayerPanel> onPanelChanged;
  final VoidCallback onClose;

  @override
  ConsumerState<DesktopPlayerWorkspace> createState() =>
      _DesktopPlayerWorkspaceState();
}

class _DesktopPlayerWorkspaceState
    extends ConsumerState<DesktopPlayerWorkspace> {
  bool _hasShownLyrics = false;
  bool _hasShownQueue = false;

  @override
  void initState() {
    super.initState();
    _markPanelMounted(widget.panel);
  }

  @override
  void didUpdateWidget(covariant DesktopPlayerWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panel != widget.panel) _markPanelMounted(widget.panel);
  }

  void _markPanelMounted(DesktopPlayerPanel panel) {
    if (panel == DesktopPlayerPanel.lyrics) {
      _hasShownLyrics = true;
    } else {
      _hasShownQueue = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));
    final visuals =
        ref.watch(playerSurfaceMediaVisualsProvider) ??
        EchoMediaVisuals.fromThemeColors(context.echoColors);

    if (song == null) {
      return const EchoEmptyState(
        title: '还没有正在播放的歌曲',
        description: '从音乐流、曲库或播放列表选择一首歌曲开始播放。',
        icon: AppIcons.music,
      );
    }

    return EchoMediaColorScope(
      visuals: visuals,
      role: EchoMediaSurfaceRole.stage,
      child: Builder(
        builder: (context) {
          final spacing = context.echoSpacing;
          return Stack(
            key: const ValueKey<String>('echo-desktop-player-workspace'),
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: EchoPlayerBackdrop(
                  visuals: visuals,
                  mode: EchoPlayerBackdropMode.stage,
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 820 || constraints.maxHeight < 520;

                  if (compact) {
                    return Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _DesktopWorkspaceHeader(
                            song: song,
                            panel: widget.panel,
                            onPanelChanged: widget.onPanelChanged,
                            onClose: widget.onClose,
                            compact: true,
                          ),
                          SizedBox(height: spacing.sm),
                          const EchoDivider(),
                          SizedBox(height: spacing.xs),
                          Expanded(child: _buildActivePanel()),
                        ],
                      ),
                    );
                  }

                  final panelPadding = spacing.xl;
                  final columnGap = spacing.xxl;
                  final artworkWidth = (constraints.maxWidth * 0.36)
                      .clamp(280.0, 440.0)
                      .toDouble();
                  final coverSize = (artworkWidth - panelPadding * 2)
                      .clamp(240.0, 400.0)
                      .toDouble();

                  return Padding(
                    padding: EdgeInsets.all(panelPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: artworkWidth,
                          child: _DesktopArtworkPane(
                            song: song,
                            size: coverSize,
                          ),
                        ),
                        SizedBox(width: columnGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _DesktopWorkspaceHeader(
                                song: song,
                                panel: widget.panel,
                                onPanelChanged: widget.onPanelChanged,
                                onClose: widget.onClose,
                              ),
                              SizedBox(height: spacing.md),
                              const EchoDivider(),
                              SizedBox(height: spacing.sm),
                              Expanded(child: _buildActivePanel()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivePanel() {
    final showLyrics = widget.panel == DesktopPlayerPanel.lyrics;
    return IndexedStack(
      index: showLyrics ? 0 : 1,
      children: <Widget>[
        _hasShownLyrics
            ? TickerMode(
                enabled: showLyrics,
                child: ExcludeFocus(
                  excluding: !showLyrics,
                  child: const CurrentLyricsPanel(
                    key: ValueKey<String>('desktop-lyrics'),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        _hasShownQueue
            ? TickerMode(
                enabled: !showLyrics,
                child: ExcludeFocus(
                  excluding: showLyrics,
                  child: const _DesktopQueuePanel(
                    key: ValueKey<String>('desktop-queue'),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}

class _DesktopArtworkPane extends StatelessWidget {
  const _DesktopArtworkPane({required this.song, required this.size});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (song.artist?.trim().isNotEmpty == true) song.artist!.trim(),
      if (song.album?.trim().isNotEmpty == true) song.album!.trim(),
    ].join(' · ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size, maxHeight: size),
          child: AspectRatio(
            aspectRatio: 1,
            child: EchoArtwork(
              coverArtId: song.artworkReference,
              semanticLabel: '${song.title} 封面',
              requestSize: 600,
              borderRadius: context.echoRadii.scene,
              heroTag: null,
            ),
          ),
        ),
        SizedBox(height: context.echoSpacing.lg),
        Text(
          song.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.echoTypography.headline.copyWith(
            color: context.echoColors.ink,
          ),
        ),
        if (subtitle.isNotEmpty) ...<Widget>[
          SizedBox(height: context.echoSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.echoTypography.body.copyWith(
              color: context.echoColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _DesktopWorkspaceHeader extends StatelessWidget {
  const _DesktopWorkspaceHeader({
    required this.song,
    required this.panel,
    required this.onPanelChanged,
    required this.onClose,
    this.compact = false,
  });

  final Song song;
  final DesktopPlayerPanel panel;
  final ValueChanged<DesktopPlayerPanel> onPanelChanged;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = context.echoSpacing;
    return Row(
      key: ValueKey<String>(
        compact
            ? 'echo-desktop-workspace-compact-header'
            : 'echo-desktop-workspace-header',
      ),
      children: <Widget>[
        if (compact) ...<Widget>[
          EchoArtwork(
            coverArtId: song.artworkReference,
            semanticLabel: '${song.title} 封面',
            size: 56,
            requestSize: 160,
            borderRadius: context.echoRadii.control,
          ),
          SizedBox(width: spacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.echoTypography.title.copyWith(
                    color: context.echoColors.ink,
                  ),
                ),
              ),
              SizedBox(height: spacing.xxs),
              Text(
                <String>[
                  if (song.artist?.trim().isNotEmpty == true)
                    song.artist!.trim(),
                  if (song.album?.trim().isNotEmpty == true) song.album!.trim(),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.echoTypography.metadata.copyWith(
                  color: context.echoColors.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.md),
        _WorkspaceTab(
          icon: AppIcons.lyrics,
          label: '歌词',
          selected: panel == DesktopPlayerPanel.lyrics,
          onPressed: () => onPanelChanged(DesktopPlayerPanel.lyrics),
        ),
        SizedBox(width: spacing.xs),
        _WorkspaceTab(
          icon: AppIcons.queue,
          label: '播放队列',
          selected: panel == DesktopPlayerPanel.queue,
          onPressed: () => onPanelChanged(DesktopPlayerPanel.queue),
        ),
        SizedBox(width: spacing.xs),
        EchoIconButton(
          icon: AppIcons.chevronDown,
          label: '返回浏览',
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? context.echoColors.accent
            : context.echoColors.muted,
        backgroundColor: selected
            ? context.echoColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: context.echoSpacing.sm,
          vertical: context.echoSpacing.xs,
        ),
      ),
    );
  }
}

class _DesktopQueuePanel extends ConsumerStatefulWidget {
  const _DesktopQueuePanel({super.key});

  @override
  ConsumerState<_DesktopQueuePanel> createState() => _DesktopQueuePanelState();
}

class _DesktopQueuePanelState extends ConsumerState<_DesktopQueuePanel> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedEntryId;
  int _locateCurrentRequestId = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(
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
    final playerState = PlayerState(
      playbackQueue: queue.playbackQueue,
      isPlaying: queue.isPlaying,
      processingState: queue.processingState,
      isSeeking: queue.isSeeking,
      isChangingSource: queue.isChangingSource,
      hasPlaybackError: queue.hasPlaybackError,
      shuffleEnabled: queue.shuffleEnabled,
      loopMode: queue.loopMode,
    );
    final notifier = ref.read(playerProvider.notifier);
    final currentIndex = playerState.currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            left: context.echoSpacing.sm,
            right: context.echoSpacing.xs,
            bottom: context.echoSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  currentIndex < 0
                      ? '队列 · ${playerState.queue.length} 首'
                      : '队列 · ${playerState.queue.length} 首 · 当前第 ${currentIndex + 1} 首',
                  style: context.echoTypography.metadata.copyWith(
                    color: context.echoColors.muted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: currentIndex < 0
                    ? null
                    : () => setState(() => _locateCurrentRequestId++),
                icon: const Icon(AppIcons.locate, size: 18),
                label: const Text('定位当前'),
              ),
              TextButton.icon(
                onPressed: playerState.queue.isEmpty
                    ? null
                    : () => unawaited(notifier.clearQueue()),
                icon: const Icon(AppIcons.clearAll, size: 18),
                label: const Text('清空后续'),
              ),
            ],
          ),
        ),
        Expanded(
          child: playerState.queue.isEmpty
              ? const EchoEmptyState(
                  title: '队列为空',
                  description: '从曲库选择歌曲后，接下来的曲目会显示在这里。',
                  icon: AppIcons.queue,
                )
              : PlaybackQueueContent(
                  scrollController: _scrollController,
                  playerState: playerState,
                  desktopInteraction: true,
                  locateCurrentRequestId: _locateCurrentRequestId,
                  selectedEntryId: _selectedEntryId,
                  onEntrySelected: (entryId) {
                    setState(() => _selectedEntryId = entryId);
                  },
                  onDeleteEntry: notifier.removeQueueEntry,
                  onSelect: (index) {
                    final entryId = playerState.queueEntryIds[index];
                    setState(() => _selectedEntryId = entryId);
                    return notifier.skipToQueueEntry(entryId);
                  },
                  onReorder: notifier.reorderQueue,
                  onOpenSongActions: (rowContext, index, song, entryId) {
                    return showSongOptionsSheet(
                      context: rowContext,
                      song: song,
                      extraActions: <SongOptionsExtraAction>[
                        SongOptionsExtraAction(
                          icon: AppIcons.removeCircle,
                          title: '从队列移除',
                          isDestructive: true,
                          onPressed: () => notifier.removeQueueEntry(entryId),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
