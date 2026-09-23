import 'package:flutter/widgets.dart';

/// Exposes desktop-only history operations to pages hosted by the desktop
/// navigator. Mobile routes continue to use their existing navigator policy.
class DesktopNavigationHistoryScope extends InheritedWidget {
  const DesktopNavigationHistoryScope({
    super.key,
    required this.popCurrentAndDiscardForward,
    required this.clearForwardHistory,
    required super.child,
  });

  final bool Function() popCurrentAndDiscardForward;
  final VoidCallback clearForwardHistory;

  static DesktopNavigationHistoryScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesktopNavigationHistoryScope>();

  @override
  bool updateShouldNotify(DesktopNavigationHistoryScope oldWidget) =>
      popCurrentAndDiscardForward != oldWidget.popCurrentAndDiscardForward ||
      clearForwardHistory != oldWidget.clearForwardHistory;
}
