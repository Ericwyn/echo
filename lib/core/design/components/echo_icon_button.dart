import 'package:flutter/material.dart';

import '../echo_context.dart';
import 'echo_pressable.dart';

class EchoIconButton extends StatelessWidget {
  const EchoIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.foregroundColor,
    this.backgroundColor,
    this.iconSize = 22,
    this.enableHaptics = false,
    this.autofocus = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double iconSize;
  final bool enableHaptics;
  final bool autofocus;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final enabled = onPressed != null && !isLoading;
    final foreground = enabled || isLoading
        ? foregroundColor ?? (selected ? colors.accent : colors.ink)
        : colors.onDisabled;
    final background =
        backgroundColor ??
        (selected
            ? colors.accent.withValues(alpha: 0.14)
            : enabled
            ? Colors.transparent
            : colors.raised.withValues(alpha: 0.7));

    return EchoPressable(
      semanticLabel: label,
      selected: selected,
      onPressed: enabled ? onPressed : null,
      minimumSize: context.echoInteraction.minimumTouchSize,
      borderRadius: context.echoRadii.control,
      enableHaptics: enableHaptics,
      autofocus: autofocus,
      child: SizedBox.square(
        dimension: context.echoInteraction.minimumTouchTarget,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: context.echoRadii.control,
          ),
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: iconSize,
                    child: CircularProgressIndicator(
                      value: MediaQuery.disableAnimationsOf(context)
                          ? 0.75
                          : null,
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}
