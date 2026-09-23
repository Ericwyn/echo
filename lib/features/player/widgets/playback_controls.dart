import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../providers/player_provider.dart';
import 'player_scrubber.dart';

/// Buffered playback progress with a 48dp interaction target.
class ProgressBar extends ConsumerStatefulWidget {
  const ProgressBar({super.key});

  @override
  ConsumerState<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<ProgressBar>
    with SingleTickerProviderStateMixin {
  double? _dragValue;
  String? _dragSongId;
  late final AnimationController _loadingOpacityController;
  late final Animation<double> _loadingOpacity;
  bool _isLoadingPulseActive = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loadingOpacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadingOpacity = Tween<double>(begin: 1, end: 0.52).animate(
      CurvedAnimation(
        parent: _loadingOpacityController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.echoReduceMotion;
    if (_reduceMotion) {
      _loadingOpacityController
        ..stop()
        ..value = 0;
      _isLoadingPulseActive = false;
    }
  }

  @override
  void dispose() {
    _loadingOpacityController.dispose();
    super.dispose();
  }

  void _syncLoadingPulse(bool shouldPulse) {
    final resolved = shouldPulse && !_reduceMotion;
    if (resolved == _isLoadingPulseActive) return;
    _isLoadingPulseActive = resolved;
    if (resolved) {
      _loadingOpacityController.repeat(reverse: true);
    } else {
      _loadingOpacityController
        ..stop()
        ..value = 0;
    }
  }

  void _clearSeekSession() {
    _dragValue = null;
    _dragSongId = null;
  }

  void _cancelSeekSession() {
    if (_dragValue == null && _dragSongId == null) return;
    setState(_clearSeekSession);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      playerProvider.select((state) => state.currentSong?.id),
      (previous, next) {
        if (previous != next) _cancelSeekSession();
      },
    );
    final state = ref.watch(
      playerProvider.select(
        (state) => (
          songId: state.currentSong?.id,
          position: state.position,
          duration: state.duration,
          buffered: state.bufferedPosition,
          isLoading: state.isLoading,
        ),
      ),
    );
    final isLoading = state.isLoading;
    _syncLoadingPulse(isLoading);

    final maxMilliseconds = state.duration.inMilliseconds > 0
        ? state.duration.inMilliseconds.toDouble()
        : 1.0;
    final activeDragValue = _dragSongId == state.songId ? _dragValue : null;
    final sliderValue =
        (activeDragValue ?? state.position.inMilliseconds.toDouble()).clamp(
          0.0,
          maxMilliseconds,
        );
    final bufferedValue = state.buffered.inMilliseconds
        .toDouble()
        .clamp(0.0, maxMilliseconds)
        .toDouble();
    final displayPosition = activeDragValue == null
        ? state.position
        : Duration(milliseconds: activeDragValue.round());
    final progressLabel =
        '${_formatDuration(displayPosition)} / ${_formatDuration(state.duration)}';
    final timeStyle = context.echoTypography.metadata.copyWith(
      color: context.echoColors.muted,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: context.echoInteraction.minimumTouchTarget,
          child: AnimatedBuilder(
            animation: _loadingOpacity,
            builder: (context, child) => Opacity(
              opacity: isLoading && !_reduceMotion ? _loadingOpacity.value : 1,
              child: child,
            ),
            child: EchoPlayerScrubber(
              key: ValueKey<String?>(state.songId),
              value: sliderValue,
              min: 0,
              max: maxMilliseconds,
              secondaryValue: bufferedValue,
              semanticStep: 10000,
              semanticLabel: '播放进度',
              semanticValue: progressLabel,
              semanticValueFormatter: (value) {
                final position = Duration(milliseconds: value.round());
                return '${_formatDuration(position)} / '
                    '${_formatDuration(state.duration)}';
              },
              activeColor: context.echoColors.accent,
              secondaryColor: context.echoColors.accent.withValues(alpha: 0.42),
              inactiveColor: context.echoColors.divider,
              thumbColor: context.echoColors.ink,
              onChangeStart: state.duration <= Duration.zero
                  ? null
                  : (value) {
                      setState(() {
                        _dragSongId = state.songId;
                        _dragValue = value;
                      });
                    },
              onChanged: state.duration <= Duration.zero
                  ? null
                  : (value) {
                      if (_dragSongId != state.songId) return;
                      setState(() => _dragValue = value);
                    },
              onChangeEnd: state.duration <= Duration.zero
                  ? null
                  : (endedValue) {
                      final sessionSongId = _dragSongId;
                      final value = (_dragValue ?? endedValue)
                          .clamp(0.0, maxMilliseconds)
                          .toDouble();
                      setState(_clearSeekSession);
                      if (sessionSongId == null ||
                          sessionSongId != state.songId) {
                        return;
                      }
                      HapticFeedback.selectionClick();
                      unawaited(
                        ref
                            .read(playbackCommandsProvider)
                            .seek(Duration(milliseconds: value.round())),
                      );
                    },
              onChangeCancel: state.duration <= Duration.zero
                  ? null
                  : (_) => _cancelSeekSession(),
            ),
          ),
        ),
        ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.echoSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_formatDuration(displayPosition), style: timeStyle),
                Text(_formatDuration(state.duration), style: timeStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes;
    final seconds = safe.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The primary transport zone contains only previous, play/pause, and next.
/// Position ticks and secondary utility state stay outside its dependency set.
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key, this.compact = false});

  // The Remix play glyph has a centered advance box, but its triangular ink
  // mass sits to the left of that center. Shift it by the measured optical
  // correction so it reads centered inside the circular transport control.
  static const double _playIconOpticalCorrection = 0.09;

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.read(playbackCommandsProvider);
    final state = ref.watch(
      playerProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isLoading: state.isLoading,
          hasPrevious: state.hasPrevious,
          hasNext: state.hasNext,
        ),
      ),
    );

    final playDimension = compact ? 56.0 : 64.0;
    final playIconSize = compact ? 30.0 : 32.0;
    final buttons = <Widget>[
      PlaybackIconButton(
        icon: AppIcons.previous,
        label: '上一首',
        iconSize: 30,
        onPressed: !state.hasPrevious
            ? null
            : () => unawaited(commands.previous()),
      ),
      PlaybackIconButton(
        icon: state.isPlaying ? AppIcons.pause : AppIcons.play,
        label: state.isLoading
            ? '加载中'
            : state.isPlaying
            ? '暂停'
            : '播放',
        isLoading: state.isLoading,
        emphasized: true,
        dimension: playDimension,
        iconSize: playIconSize,
        iconOffset: state.isPlaying
            ? Offset.zero
            : Offset(playIconSize * _playIconOpticalCorrection, 0),
        onPressed: state.isLoading
            ? null
            : () => unawaited(commands.togglePlayPause()),
      ),
      PlaybackIconButton(
        icon: AppIcons.next,
        label: '下一首',
        iconSize: 30,
        onPressed: !state.hasNext ? null : () => unawaited(commands.next()),
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttons,
        ),
      ),
    );
  }
}

class PlaybackIconButton extends StatelessWidget {
  const PlaybackIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.emphasized = false,
    this.dimension = 48,
    this.iconSize = 22,
    this.iconOffset = Offset.zero,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool emphasized;
  final double dimension;
  final double iconSize;
  final Offset iconOffset;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final enabled = onPressed != null;
    final foreground = emphasized
        ? EchoColors.readableOn(colors.ink)
        : enabled
        ? colors.ink
        : colors.onDisabled;
    final background = emphasized
        ? colors.ink
        : selected
        ? colors.ink.withValues(alpha: 0.14)
        : Colors.transparent;

    return EchoPressable(
      semanticLabel: label,
      selected: selected,
      onPressed: onPressed,
      enableHaptics: true,
      minimumSize: Size.square(dimension),
      borderRadius: context.echoRadii.pill,
      child: SizedBox.square(
        dimension: dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: context.echoRadii.pill,
            border: !emphasized && selected
                ? Border.all(color: colors.accent)
                : null,
          ),
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: iconSize,
                    child: CircularProgressIndicator(
                      value: MediaQuery.disableAnimationsOf(context)
                          ? 0.75
                          : null,
                      strokeWidth: 2.5,
                      color: foreground,
                    ),
                  )
                : Transform.translate(
                    key: emphasized
                        ? const ValueKey<String>(
                            'full_player_primary_transport_glyph',
                          )
                        : null,
                    offset: iconOffset,
                    child: Icon(icon, size: iconSize, color: foreground),
                  ),
          ),
        ),
      ),
    );
  }
}
