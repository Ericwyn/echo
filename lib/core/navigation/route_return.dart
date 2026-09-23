import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'desktop_navigation_history_scope.dart';

/// Returns from a pushed flow using the nearest Navigator, with a safe route
/// fallback for pages opened directly without a previous page.
void popCurrentRouteOrGoHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    GoRouter.of(context).go('/home');
  }
}

/// Returns from a route whose underlying entity has been deleted.
///
/// Desktop forward history must not recreate an editor or detail page for an
/// entity that no longer exists. On mobile there is no shared desktop history,
/// so this follows the normal nearest-Navigator return behavior.
void popCurrentRouteAndDiscardForwardOrGoHome(BuildContext context) {
  final desktopHistory = DesktopNavigationHistoryScope.maybeOf(context);
  if (desktopHistory == null) {
    popCurrentRouteOrGoHome(context);
    return;
  }

  if (desktopHistory.popCurrentAndDiscardForward()) return;
  desktopHistory.clearForwardHistory();
  GoRouter.of(context).go('/home');
}
