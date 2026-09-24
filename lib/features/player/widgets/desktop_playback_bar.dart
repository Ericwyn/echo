import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../core/design/echo_design.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/echo_artwork.dart';
import '../pages/desktop_player_workspace.dart';
import 'playback_controls.dart'
    show PlaybackControls, PlaybackIconButton, ProgressBar;
import 'player_scrubber.dart';

/// Persistent desktop controls. Phone and tablet layouts continue to use the
/// gesture-oriented MiniPlayer.
class DesktopPlaybackBar extends ConsumerWidget {
  const DesktopPlaybackBar({super.key, required this.onOpenWorkspace});

  static const double height = echoDesktopPlaybackBarHeight;

  final ValueChanged<DesktopPlayerPanel> onOpenWorkspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(
      playbackSnapshotProvider.select(
        (snapshot) => (
          songId: snapshot.songId,
          title: snapshot.title,
          artist: snapshot.artist,
          artworkReference: snapshot.artworkReference,
          shuffle: snapshot.shuffleEnabled,
          loopMode: snapshot.loopMode,
        ),
      ),
    );
    if (playback.songId == null) return const SizedBox.shrink();
    final commands = ref.read(playbackCommandsProvider);

    final mode = playback.loopMode == LoopMode.one
        ? PlaybackMode.repeatOne
        : playback.loopMode == LoopMode.all
        ? PlaybackMode.repeatAll
        : PlaybackMode.sequential;
    final modeIcon = switch (mode) {
      PlaybackMode.sequential || PlaybackMode.repeatAll => AppIcons.repeat,
      PlaybackMode.repeatOne => AppIcons.repeatOne,
      PlaybackMode.shuffle => AppIcons.shuffle,
    };
    final modeLabel = switch (mode) {
      PlaybackMode.sequential => '顺序播放',
      PlaybackMode.repeatAll => '列表循环',
      PlaybackMode.repeatOne => '单曲循环',
      PlaybackMode.shuffle => '随机播放',
    };

    return Material(
      color: context.echoColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          final tight = constraints.maxWidth < 720;
          final trackWidth = compact
              ? tight
                    ? 112.0
                    : 164.0
              : 248.0;
          final spacing = context.echoSpacing;
          return Container(
            key: const ValueKey<String>('echo-desktop-playback-bar'),
            height: height,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.echoColors.divider),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? spacing.sm : spacing.lg,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: trackWidth,
                  child: _DesktopCurrentTrack(
                    title: playback.title,
                    artist: playback.artist,
                    artworkReference: playback.artworkReference,
                    artworkSize: compact ? 40 : 56,
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                  ),
                ),
                SizedBox(
                  width: tight
                      ? spacing.xxs
                      : compact
                      ? spacing.sm
                      : spacing.lg,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          PlaybackIconButton(
                            icon: AppIcons.shuffle,
                            label: playback.shuffle ? '关闭随机播放' : '开启随机播放',
                            selected: playback.shuffle,
                            dimension: 40,
                            iconSize: 20,
                            onPressed: () => unawaited(
                              commands.setShuffleEnabled(!playback.shuffle),
                            ),
                          ),
                          SizedBox(width: spacing.xxs),
                          const PlaybackControls(compact: true),
                          SizedBox(width: spacing.xxs),
                          PlaybackIconButton(
                            icon: modeIcon,
                            label: '$modeLabel，点击切换',
                            selected: mode != PlaybackMode.sequential,
                            dimension: 40,
                            iconSize: 20,
                            onPressed: () =>
                                unawaited(commands.cycleLoopMode()),
                          ),
                        ],
                      ),
                      const ProgressBar(centerTrack: true, compactLabels: true),
                    ],
                  ),
                ),
                SizedBox(width: compact ? spacing.xxs : spacing.sm),
                _DesktopVolumeControl(compact: compact),
                SizedBox(width: compact ? spacing.xxs : spacing.md),
                if (compact)
                  PlaybackIconButton(
                    icon: AppIcons.lyrics,
                    label: '打开歌词',
                    dimension: 40,
                    iconSize: 20,
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                  )
                else
                  EchoIconButton(
                    icon: AppIcons.lyrics,
                    label: '打开歌词',
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                  ),
                if (compact)
                  PlaybackIconButton(
                    icon: AppIcons.queue,
                    label: '打开播放队列',
                    dimension: 40,
                    iconSize: 20,
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.queue),
                  )
                else
                  EchoIconButton(
                    icon: AppIcons.queue,
                    label: '打开播放队列',
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.queue),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DesktopCurrentTrack extends StatelessWidget {
  const _DesktopCurrentTrack({
    required this.title,
    required this.artist,
    required this.artworkReference,
    required this.artworkSize,
    required this.onPressed,
  });

  final String title;
  final String artist;
  final String? artworkReference;
  final double artworkSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: context.echoRadii.control,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.echoSpacing.xxs),
        child: Row(
          children: <Widget>[
            EchoArtwork(
              coverArtId: artworkReference,
              semanticLabel: '$title 封面',
              size: artworkSize,
              requestSize: 160,
              borderRadius: context.echoRadii.control,
            ),
            SizedBox(width: context.echoSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.echoTypography.body.copyWith(
                      color: context.echoColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (artist.isNotEmpty)
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.echoTypography.metadata.copyWith(
                        color: context.echoColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopVolumeControl extends ConsumerWidget {
  const _DesktopVolumeControl({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.read(playbackCommandsProvider);
    final volume = ref.watch(
      playbackSnapshotProvider.select(
        (snapshot) => (value: snapshot.volume, muted: snapshot.isMuted),
      ),
    );
    final colors = context.echoColors;
    final spacing = context.echoSpacing;
    final menuWidth = compact ? 220.0 : 244.0;
    var menuVolume = volume.value;
    final icon = volume.muted || volume.value == 0
        ? Icons.volume_off_outlined
        : volume.value < 0.5
        ? Icons.volume_down_outlined
        : Icons.volume_up_outlined;

    return MenuAnchor(
      menuChildren: <Widget>[
        StatefulBuilder(
          builder: (context, setMenuState) {
            final percent = (menuVolume * 100).round();
            return SizedBox(
              width: menuWidth,
              height: 64,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                child: Row(
                  children: <Widget>[
                    Text('音量', style: context.echoTypography.body),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: EchoPlayerScrubber(
                        value: menuVolume,
                        min: 0,
                        max: 1,
                        semanticStep: 0.05,
                        semanticValueFormatter: (value) =>
                            '${(value * 100).round()}%',
                        semanticLabel: '播放音量',
                        semanticValue: '$percent%',
                        onChanged: (value) {
                          setMenuState(() => menuVolume = value);
                          unawaited(commands.setUserVolume(value));
                        },
                        activeColor: colors.accent,
                        inactiveColor: colors.divider,
                        thumbColor: colors.ink,
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.end,
                        style: context.echoTypography.metadata.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: SizedBox(
            width: menuWidth,
            child: Divider(color: colors.divider, height: spacing.sm),
          ),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            volume.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          ),
          onPressed: () => unawaited(commands.setMuted(!volume.muted)),
          child: Text(volume.muted ? '取消静音' : '静音'),
        ),
      ],
      builder: (context, controller, _) {
        final label = volume.muted ? '音量控制，当前静音' : '音量控制';
        final onPressed = controller.isOpen
            ? controller.close
            : controller.open;
        if (compact) {
          return PlaybackIconButton(
            icon: icon,
            label: label,
            selected: controller.isOpen,
            dimension: 40,
            iconSize: 20,
            onPressed: onPressed,
          );
        }
        return EchoIconButton(
          icon: icon,
          label: label,
          selected: controller.isOpen,
          onPressed: onPressed,
        );
      },
    );
  }
}
