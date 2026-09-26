import 'package:echoes/core/design/tokens/echo_breakpoints.dart';
import 'package:echoes/core/design/tokens/echo_interaction.dart';
import 'package:echoes/core/design/tokens/echo_motion.dart';
import 'package:echoes/core/design/tokens/echo_radii.dart';
import 'package:echoes/core/design/tokens/echo_spacing.dart';
import 'package:echoes/core/design/tokens/echo_typography.dart';
import 'package:echoes/core/theme/color_scheme.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

const _windowsFontFamily = 'Microsoft YaHei UI';
const _windowsFontFamilyFallback = <String>['Microsoft YaHei', 'Segoe UI'];

/// Flutter compatibility theme backed entirely by Echo semantic tokens.
///
/// Visible component silhouettes belong to Echo components, not this class.
abstract final class AppTheme {
  static ThemeData light({Color? seedColor}) {
    return _build(Brightness.light, seedColor);
  }

  static ThemeData dark({Color? seedColor}) {
    return _build(Brightness.dark, seedColor);
  }

  static ThemeData _build(Brightness brightness, Color? seedColor) {
    final colors = AppColorScheme.colorsFor(brightness, seedColor);
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final typography = EchoTypography.standard(
      colors,
      fontFamily: windows ? _windowsFontFamily : null,
      fontFamilyFallback: windows ? _windowsFontFamilyFallback : null,
    );
    final colorScheme = AppColorScheme.materialBridge(colors, brightness);
    final textTheme = TextTheme(
      displayLarge: typography.display,
      displayMedium: typography.display,
      displaySmall: typography.headline,
      headlineLarge: typography.headline,
      headlineMedium: typography.headline,
      headlineSmall: typography.title,
      titleLarge: typography.title,
      titleMedium: typography.title,
      titleSmall: typography.label,
      bodyLarge: typography.body,
      bodyMedium: typography.body,
      bodySmall: typography.metadata,
      labelLarge: typography.label,
      labelMedium: typography.label,
      labelSmall: typography.metadata,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: colors.accent,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      disabledColor: colors.onDisabled,
      dividerColor: Colors.transparent,
      focusColor: colors.accent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      shadowColor: Colors.transparent,
      hintColor: colors.muted,
      unselectedWidgetColor: colors.muted,
      applyElevationOverlayColor: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      fontFamily: windows ? _windowsFontFamily : null,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        colors,
        typography,
        EchoSpacing.standard,
        EchoRadii.standard,
        EchoMotion.standard,
        EchoInteraction.standard,
        EchoBreakpoints.standard,
      ],
    );
  }
}
