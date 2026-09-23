import 'package:flutter/material.dart';

import 'player_hero_helpers.dart';

/// Shared song title/subtitle presentation used by mini and full players.
class PlayerTrackIdentity extends StatelessWidget {
  const PlayerTrackIdentity({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.subtitleStyle,
    this.textAlign = TextAlign.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.overflow,
    this.useHero = true,
    this.subtitleGap = 0,
    this.scrollable = true,
  });

  final String title;
  final String subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
  final int? titleMaxLines;
  final int? subtitleMaxLines;
  final TextOverflow? overflow;
  final bool useHero;
  final double subtitleGap;
  final bool scrollable;

  Widget _buildText({
    required String value,
    required TextStyle style,
    required String heroTag,
    int? maxLines,
  }) {
    final text = Material(
      type: MaterialType.transparency,
      child: Text(
        value,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
    if (!useHero) return text;

    return Hero(
      tag: heroTag,
      createRectTween: playerLinearRectTween,
      flightShuttleBuilder: playerTextFlightShuttleBuilder,
      child: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        _buildText(
          value: title,
          style: titleStyle,
          heroTag: playerTitleHeroTag,
          maxLines: titleMaxLines,
        ),
        if (subtitle.isNotEmpty) ...<Widget>[
          if (subtitleGap > 0) SizedBox(height: subtitleGap),
          _buildText(
            value: subtitle,
            style: subtitleStyle,
            heroTag: playerSubtitleHeroTag,
            maxLines: subtitleMaxLines,
          ),
        ],
      ],
    );

    if (!scrollable) return identity;
    return SingleChildScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      child: identity,
    );
  }
}
