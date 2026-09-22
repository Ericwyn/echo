import 'package:flutter/material.dart';

import '../../../core/design/echo_design.dart';

class LibraryDestinationRow extends StatelessWidget {
  const LibraryDestinationRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return EchoPressable(
      semanticLabel: '$title，$detail',
      onPressed: onPressed,
      minimumSize: const Size(double.infinity, 72),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.echoSpacing.xs,
          vertical: context.echoSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: context.echoInteraction.minimumTouchTarget,
              child: Center(
                child: Icon(icon, size: 24, color: context.echoColors.accent),
              ),
            ),
            SizedBox(width: context.echoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.echoTypography.title),
                  SizedBox(height: context.echoSpacing.xxs),
                  Text(
                    detail,
                    style: context.echoTypography.body.copyWith(
                      color: context.echoColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.echoSpacing.xs),
            Icon(
              AppIcons.chevronRight,
              size: 20,
              color: context.echoColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
