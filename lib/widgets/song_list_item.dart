import 'package:flutter/material.dart';

import '../core/design/echo_design.dart';
import '../data/models/song.dart';
import 'echo_artwork.dart';
import 'echo_metadata_line.dart';

enum EchoSongRowVariant { albumTrack, standard, topRank }

/// A media-first song row with explicit playback and availability states.
class EchoSongRow extends StatelessWidget {
  const EchoSongRow({
    super.key,
    required this.song,
    this.index = 0,
    this.variant = EchoSongRowVariant.standard,
    this.showAlbumMetadata = false,
    this.rank,
    this.coverArtId,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    this.innerPadding = EdgeInsets.zero,
    this.onPressed,
    this.onLongPress,
    this.onKeyboardActivate,
    this.keyboardSpaceActivates = true,
    this.onMorePressed,
    this.onPlayPressed,
    this.playSemanticLabel,
    this.moreSemanticLabel,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.isCurrent = false,
    this.isDimmed = false,
    this.currentStatusLabel,
    this.currentIndicatorIcon,
    this.isCurrentLoading = false,
    this.isDownloaded = false,
    this.isFavorite,
    this.isPreview,
  });

  static const double _coverSize = 48;
  static const double _numberWidth = 36;

  final Song song;
  final int index;
  final EchoSongRowVariant variant;
  final bool showAlbumMetadata;
  final int? rank;
  final String? coverArtId;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry innerPadding;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onKeyboardActivate;
  final bool keyboardSpaceActivates;
  final VoidCallback? onMorePressed;
  final VoidCallback? onPlayPressed;
  final String? playSemanticLabel;
  final String? moreSemanticLabel;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final bool isCurrent;
  final bool isDimmed;
  final String? currentStatusLabel;
  final IconData? currentIndicatorIcon;
  final bool isCurrentLoading;
  final bool isDownloaded;
  final bool? isFavorite;
  final bool? isPreview;

  bool get _favorite => isFavorite ?? song.starred;
  bool get _preview => isPreview ?? song.isPreview;

  @override
  Widget build(BuildContext context) {
    final artist = song.artist?.trim();
    final artistText = artist != null && artist.isNotEmpty ? artist : '-';
    final selectionAction = onToggleSelected ?? onPressed;
    final mainAction = selectionMode ? selectionAction : onPressed;
    final mainLongPress = selectionMode ? selectionAction : onLongPress;
    final moreAction = selectionMode ? null : onMorePressed ?? onLongPress;
    final isSelected = selectionMode ? selected : selected || isCurrent;
    final semanticLabel = selectionMode
        ? <String>[
            song.title,
            artistText,
            if (showAlbumMetadata && song.album?.trim().isNotEmpty == true)
              song.album!.trim(),
            song.durationString,
            if (selected) '已选择',
          ].join('，')
        : _buildSemanticLabel(artistText);
    final mainContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildLeading(context),
        SizedBox(width: context.echoSpacing.sm),
        Expanded(child: _buildDetails(context, artistText)),
      ],
    );
    final hasMainAction = mainAction != null || mainLongPress != null;
    final main = hasMainAction
        ? EchoPressable(
            semanticLabel: semanticLabel,
            selected: isSelected ? true : (selectionMode ? false : null),
            onPressed: mainAction,
            onLongPress: mainLongPress,
            onKeyboardActivate: onKeyboardActivate,
            keyboardSpaceActivates: keyboardSpaceActivates,
            minimumSize: const Size(0, 48),
            borderRadius: context.echoRadii.control,
            child: mainContent,
          )
        : Semantics(
            container: true,
            selected: isSelected ? true : (selectionMode ? false : null),
            label: semanticLabel,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: mainContent,
              ),
            ),
          );

    return AnimatedContainer(
      duration: context.echoMotion.resolve(
        context,
        context.echoMotion.feedback,
      ),
      curve: context.echoMotion.easeOut,
      margin: contentPadding,
      padding: innerPadding,
      decoration: BoxDecoration(
        color: selected
            ? context.echoColors.accent.withValues(alpha: 0.1)
            : isCurrent
            ? context.echoColors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: context.echoRadii.control,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: main),
          if (selectionMode && selectionAction != null) ...<Widget>[
            SizedBox(width: context.echoSpacing.xs),
            EchoIconButton(
              icon: selected ? AppIcons.checkCircle : AppIcons.radio,
              label: selected ? '取消选择 ${song.title}' : '选择 ${song.title}',
              selected: selected,
              onPressed: selectionAction,
            ),
          ] else ...<Widget>[
            if (onPlayPressed != null) ...<Widget>[
              SizedBox(width: context.echoSpacing.xs),
              EchoIconButton(
                icon: AppIcons.play,
                label: playSemanticLabel ?? '播放 ${song.title}',
                onPressed: onPlayPressed,
              ),
            ],
            if (moreAction != null) ...<Widget>[
              SizedBox(width: context.echoSpacing.xs),
              EchoIconButton(
                icon: AppIcons.more,
                label: moreSemanticLabel ?? '${song.title}，更多操作',
                onPressed: moreAction,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, String artistText) {
    final showFullText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final dimmedTextColor = isDimmed && !isCurrent
        ? EchoColors.ensureColorContrast(
            Color.lerp(
              context.echoColors.muted,
              context.echoColors.surface,
              0.45,
            )!,
            background: context.echoColors.surface,
            minimumRatio: 3.5,
          )
        : null;
    final statusMarkers = <Widget>[
      if (_favorite)
        const _SongStatusMarker(icon: AppIcons.heart, label: '已收藏'),
      if (isDownloaded)
        const _SongStatusMarker(icon: AppIcons.download, label: '已下载'),
      if (_preview) const _SongStatusMarker(icon: AppIcons.cloud, label: '试听'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          song.title,
          maxLines: showFullText ? null : 2,
          overflow: showFullText ? TextOverflow.visible : TextOverflow.ellipsis,
          style: context.echoTypography.title.copyWith(
            color: isCurrent
                ? context.echoColors.accent
                : isDimmed
                ? dimmedTextColor
                : context.echoColors.ink,
          ),
        ),
        SizedBox(height: context.echoSpacing.xxs),
        EchoMetadataLine(
          items: <String?>[
            artistText,
            if (showAlbumMetadata) song.album,
            song.durationString,
          ],
          style: dimmedTextColor == null
              ? null
              : context.echoTypography.metadata.copyWith(
                  color: dimmedTextColor,
                ),
          maxLines: showFullText ? null : 2,
        ),
        if (statusMarkers.isNotEmpty) ...<Widget>[
          SizedBox(height: context.echoSpacing.xxs),
          ExcludeSemantics(
            child: Wrap(
              spacing: context.echoSpacing.sm,
              runSpacing: context.echoSpacing.xxs,
              children: statusMarkers,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeading(BuildContext context) {
    return switch (variant) {
      EchoSongRowVariant.standard => SizedBox.square(
        dimension: _coverSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: EchoArtwork(
                coverArtId: coverArtId ?? song.artworkReference,
                semanticLabel: '${song.title} 封面',
                requestSize: 192,
                borderRadius: context.echoRadii.detail,
              ),
            ),
            if (isCurrent)
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: _CurrentPlayingBadge(
                  background: context.echoColors.accent,
                  foreground: context.echoColors.onAccent,
                  icon: currentIndicatorIcon ?? AppIcons.equalizer,
                  isLoading: isCurrentLoading,
                ),
              ),
          ],
        ),
      ),
      EchoSongRowVariant.albumTrack => _NumberLeading(
        value: song.track ?? index + 1,
        isCurrent: isCurrent,
      ),
      EchoSongRowVariant.topRank => _NumberLeading(
        value: rank ?? index + 1,
        isCurrent: isCurrent,
        prominent: true,
      ),
    };
  }

  String _buildSemanticLabel(String artistText) {
    return <String>[
      if (isCurrent) currentStatusLabel ?? '正在播放',
      if (isDimmed) '当前之前',
      song.title,
      artistText,
      if (showAlbumMetadata && song.album?.trim().isNotEmpty == true)
        song.album!.trim(),
      song.durationString,
      if (_favorite) '已收藏',
      if (isDownloaded) '已下载',
      if (_preview) '试听',
    ].join('，');
  }
}

class _NumberLeading extends StatelessWidget {
  const _NumberLeading({
    required this.value,
    required this.isCurrent,
    this.prominent = false,
  });

  final int value;
  final bool isCurrent;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: EchoSongRow._numberWidth,
      child: Center(
        child: isCurrent
            ? Icon(
                AppIcons.equalizer,
                size: 20,
                color: context.echoColors.accent,
              )
            : Text(
                '$value',
                textAlign: TextAlign.center,
                style:
                    (prominent
                            ? context.echoTypography.title
                            : context.echoTypography.metadata)
                        .copyWith(
                          color: context.echoColors.muted,
                          fontWeight: prominent ? FontWeight.w700 : null,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
              ),
      ),
    );
  }
}

class _CurrentPlayingBadge extends StatelessWidget {
  const _CurrentPlayingBadge({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.isLoading,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.echoRadii.pill,
        border: Border.all(color: context.echoColors.surface, width: 2),
      ),
      child: SizedBox.square(
        dimension: 20,
        child: Center(
          child: isLoading
              ? SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: foreground,
                  ),
                )
              : Icon(icon, size: 12, color: foreground),
        ),
      ),
    );
  }
}

class _SongStatusMarker extends StatelessWidget {
  const _SongStatusMarker({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: context.echoColors.muted),
        SizedBox(width: context.echoSpacing.xxs),
        Text(
          label,
          style: context.echoTypography.metadata.copyWith(
            color: context.echoColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Backwards-compatible variants used by existing library pages.
enum SongListItemVariant { albumTrack, standard }

/// Compatibility wrapper for call sites that still use [SongListItem].
class SongListItem extends StatelessWidget {
  const SongListItem({
    super.key,
    required this.song,
    required this.index,
    required this.variant,
    this.coverArtId,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    this.onTap,
    this.onLongPress,
    this.onMorePressed,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.isCurrent = false,
    this.isDownloaded = false,
    this.isFavorite,
    this.isPreview,
  });

  final Song song;
  final int index;
  final SongListItemVariant variant;
  final String? coverArtId;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMorePressed;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final bool isCurrent;
  final bool isDownloaded;
  final bool? isFavorite;
  final bool? isPreview;

  @override
  Widget build(BuildContext context) {
    return EchoSongRow(
      song: song,
      index: index,
      variant: switch (variant) {
        SongListItemVariant.albumTrack => EchoSongRowVariant.albumTrack,
        SongListItemVariant.standard => EchoSongRowVariant.standard,
      },
      coverArtId: coverArtId,
      contentPadding: contentPadding,
      onPressed: onTap,
      onLongPress: onLongPress,
      onMorePressed: onMorePressed,
      selectionMode: selectionMode,
      selected: selected,
      onToggleSelected: onToggleSelected,
      isCurrent: isCurrent,
      isDownloaded: isDownloaded,
      isFavorite: isFavorite,
      isPreview: isPreview,
    );
  }
}
