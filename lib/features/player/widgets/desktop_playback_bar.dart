import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../core/design/echo_design.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/echo_artwork.dart';
import '../pages/desktop_player_workspace.dart';
import 'playback_controls.dart' show PlaybackControls, ProgressBar;
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
          final trackWidth = compact
              ? constraints.maxWidth < 720
                    ? 164.0
                    : 188.0
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
              vertical: spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: trackWidth,
                  child: _DesktopCurrentTrack(
                    title: playback.title,
                    artist: playback.artist,
                    artworkReference: playback.artworkReference,
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                  ),
                ),
                SizedBox(width: compact ? spacing.sm : spacing.lg),
                if (!compact)
                  EchoIconButton(
                    icon: AppIcons.shuffle,
                    label: playback.shuffle ? '关闭随机播放' : '开启随机播放',
                    selected: playback.shuffle,
                    onPressed: () => unawaited(
                      commands.setShuffleEnabled(!playback.shuffle),
                    ),
                  ),
                const PlaybackControls(compact: true),
                if (!compact)
                  EchoIconButton(
                    icon: modeIcon,
                    label: '$modeLabel，点击切换',
                    selected: mode != PlaybackMode.sequential,
                    onPressed: () => unawaited(commands.cycleLoopMode()),
                  ),
                SizedBox(width: compact ? spacing.xs : spacing.md),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Expanded(child: ProgressBar()),
                      if (!compact) ...<Widget>[
                        SizedBox(width: spacing.md),
                        const _DesktopVolumeControl(),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: compact ? spacing.xs : spacing.md),
                if (compact)
                  _CompactPlaybackOptions(
                    shuffle: playback.shuffle,
                    modeIcon: modeIcon,
                    modeLabel: modeLabel,
                  ),
                EchoIconButton(
                  icon: AppIcons.lyrics,
                  label: '打开歌词',
                  onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                ),
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
    required this.onPressed,
  });

  final String title;
  final String artist;
  final String? artworkReference;
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
              size: 56,
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
  const _DesktopVolumeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.read(playbackCommandsProvider);
    final volume = ref.watch(
      playbackSnapshotProvider.select(
        (snapshot) => (value: snapshot.volume, muted: snapshot.isMuted),
      ),
    );
    final icon = volume.muted || volume.value == 0
        ? Icons.volume_off_outlined
        : volume.value < 0.5
        ? Icons.volume_down_outlined
        : Icons.volume_up_outlined;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EchoIconButton(
          icon: icon,
          label: volume.muted ? '取消静音' : '静音',
          onPressed: () => unawaited(commands.setMuted(!volume.muted)),
        ),
        SizedBox(
          width: 112,
          child: EchoPlayerScrubber(
            value: volume.value,
            min: 0,
            max: 1,
            semanticStep: 0.05,
            semanticValueFormatter: (value) => '${(value * 100).round()}%',
            semanticLabel: '播放音量',
            semanticValue: '${(volume.value * 100).round()}%',
            onChanged: (value) => unawaited(commands.setUserVolume(value)),
            activeColor: context.echoColors.accent,
            inactiveColor: context.echoColors.divider,
            thumbColor: context.echoColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Keeps volume adjustment and playback modes available when the desktop
/// player bar is too narrow to show every control inline.
class _CompactPlaybackOptions extends ConsumerWidget {
  const _CompactPlaybackOptions({
    required this.shuffle,
    required this.modeIcon,
    required this.modeLabel,
  });

  final bool shuffle;
  final IconData modeIcon;
  final String modeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.echoColors;
    final spacing = context.echoSpacing;
    final volume = ref.watch(
      playbackSnapshotProvider.select(
        (snapshot) => (value: snapshot.volume, muted: snapshot.isMuted),
      ),
    );
    final commands = ref.read(playbackCommandsProvider);
    var menuVolume = volume.value;

    return MenuAnchor(
      menuChildren: <Widget>[
        StatefulBuilder(
          builder: (context, setMenuState) {
            final percent = (menuVolume * 100).round();
            return SizedBox(
              width: 244,
              height: 68,
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
            width: 244,
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
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.shuffle),
          trailingIcon: shuffle ? const Icon(AppIcons.check) : null,
          onPressed: () => unawaited(commands.setShuffleEnabled(!shuffle)),
          child: Text(shuffle ? '关闭随机播放' : '开启随机播放'),
        ),
        MenuItemButton(
          leadingIcon: Icon(modeIcon),
          trailingIcon: const Icon(AppIcons.chevronRight),
          onPressed: () => unawaited(commands.cycleLoopMode()),
          child: Text('$modeLabel，点击切换'),
        ),
      ],
      builder: (context, controller, _) => EchoIconButton(
        icon: AppIcons.tune,
        label: '音量与播放模式',
        onPressed: controller.isOpen ? controller.close : controller.open,
      ),
    );
  }
}
