import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../core/design/echo_design.dart';
import '../../../data/models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/echo_artwork.dart';
import '../pages/desktop_player_workspace.dart';
import '../pages/full_player_page.dart' show PlaybackControls, ProgressBar;
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
      playerProvider.select(
        (state) => (
          song: state.currentSong,
          shuffle: state.shuffleEnabled,
          loopMode: state.loopMode,
        ),
      ),
    );
    final song = playback.song;
    if (song == null) return const SizedBox.shrink();

    final mode = playback.shuffle
        ? PlaybackMode.shuffle
        : playback.loopMode == LoopMode.one
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
          final spacing = context.echoSpacing;
          return Container(
            key: const ValueKey<String>('echo-desktop-playback-bar'),
            height: height,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.echoColors.controlBoundary),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? spacing.sm : spacing.lg,
              vertical: spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: compact ? 188 : 248,
                  child: _DesktopCurrentTrack(
                    song: song,
                    onPressed: () => onOpenWorkspace(DesktopPlayerPanel.lyrics),
                  ),
                ),
                SizedBox(width: compact ? spacing.sm : spacing.lg),
                if (!compact)
                  EchoIconButton(
                    icon: AppIcons.shuffle,
                    label: playback.shuffle ? '关闭随机播放' : '开启随机播放',
                    selected: playback.shuffle,
                    onPressed: () =>
                        ref.read(playerProvider.notifier).toggleShuffle(),
                  ),
                const PlaybackControls(compact: true),
                if (!compact)
                  EchoIconButton(
                    icon: modeIcon,
                    label: '$modeLabel，点击切换',
                    selected: mode != PlaybackMode.sequential,
                    onPressed: () =>
                        ref.read(playerProvider.notifier).cyclePlaybackMode(),
                  ),
                SizedBox(width: compact ? spacing.xs : spacing.md),
                const Expanded(child: ProgressBar()),
                SizedBox(width: compact ? spacing.xs : spacing.md),
                if (!compact) const _DesktopVolumeControl(showSlider: true),
                if (compact) const _DesktopVolumeControl(showSlider: false),
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
  const _DesktopCurrentTrack({required this.song, required this.onPressed});

  final Song song;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final artist = song.artist?.trim() ?? '';
    return InkWell(
      onTap: onPressed,
      borderRadius: context.echoRadii.control,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.echoSpacing.xxs),
        child: Row(
          children: <Widget>[
            EchoArtwork(
              coverArtId: song.artworkReference,
              semanticLabel: '${song.title} 封面',
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
                    song.title,
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
  const _DesktopVolumeControl({required this.showSlider});

  final bool showSlider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(
      playerProvider.select(
        (state) => (value: state.userVolume, muted: state.isMuted),
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
          onPressed: () => ref.read(playerProvider.notifier).toggleMuted(),
        ),
        if (showSlider)
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
              onChanged: (value) =>
                  ref.read(playerProvider.notifier).setUserVolume(value),
              activeColor: context.echoColors.accent,
              inactiveColor: context.echoColors.divider,
              thumbColor: context.echoColors.ink,
            ),
          ),
      ],
    );
  }
}
