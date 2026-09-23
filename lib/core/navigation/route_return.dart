import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
