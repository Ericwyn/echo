import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../providers/lyrics_cover_provider.dart';
import 'synced_lyrics_view.dart';

/// The current-song lyric surface, shared by the immersive phone player and
/// the persistent desktop playback workspace.
class CurrentLyricsPanel extends ConsumerWidget {
  const CurrentLyricsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);
    return lyricsAsync.when(
      data: (lyrics) {
        final bestLyrics = lyrics?.getBest();
        if (bestLyrics == null) {
          return const _LyricsMessage(
            icon: AppIcons.lyrics,
            title: '暂无歌词',
            description: '当前曲目没有可用的歌词内容。',
          );
        }
        return SyncedLyricsView(
          lyrics: bestLyrics,
          activePrimaryColor: context.echoColors.ink,
          activeSecondaryColor: context.echoColors.ink,
          inactivePrimaryColor: context.echoColors.muted,
          inactiveSecondaryColor: context.echoColors.muted,
        );
      },
      loading: () => const _LyricsLoading(),
      error: (error, stackTrace) => _LyricsMessage(
        icon: AppIcons.error,
        title: '歌词加载失败',
        description: '播放不受影响，可以立即重试。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(currentLyricsProvider),
      ),
    );
  }
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.echoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              label: '$title，$description',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 32, color: context.echoColors.ink),
                    SizedBox(height: context.echoSpacing.sm),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.echoTypography.title.copyWith(
                        color: context.echoColors.ink,
                      ),
                    ),
                    SizedBox(height: context.echoSpacing.xs),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: context.echoTypography.body.copyWith(
                        color: context.echoColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              SizedBox(height: context.echoSpacing.lg),
              EchoButton.secondary(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '歌词加载中',
      child: ExcludeSemantics(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final width in <double>[220, 280, 196, 250]) ...<Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.echoColors.ink.withValues(alpha: 0.18),
                    borderRadius: context.echoRadii.detail,
                  ),
                  child: SizedBox(width: width, height: 16),
                ),
                SizedBox(height: context.echoSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
