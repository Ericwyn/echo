import 'package:flutter/material.dart';

import '../../core/design/components/echo_page_route.dart';
import '../../core/navigation/desktop_navigation_history_scope.dart';
import '../../providers/navigation_provider.dart';

const _desktopDestinationRoutePrefix = 'desktop-destination:';

typedef DesktopNavigationStateChanged =
    void Function(String? destinationId, int branchIndex);

/// Desktop navigation policy: one Music Flow root, replaceable sidebar
/// destinations, and a shared push/pop history for content details.
///
/// The mobile app continues to use its StatefulShellRoute branch navigators.
class DesktopNavigationStrategy {
  DesktopNavigationStrategy({required DesktopNavigationStateChanged onChanged})
    : navigatorKey = GlobalKey<NavigatorState>(),
      _observer = _DesktopNavigationObserver(onChanged);

  final GlobalKey<NavigatorState> navigatorKey;
  final _DesktopNavigationObserver _observer;

  bool get canGoBack => navigatorKey.currentState?.canPop() ?? false;
  bool get canGoForward => _observer.canGoForward;

  Widget buildNavigator(BuildContext context, {required Widget rootPage}) {
    return DesktopNavigationHistoryScope(
      popCurrentAndDiscardForward: popCurrentAndDiscardForward,
      clearForwardHistory: _observer.clearForwardHistory,
      child: Navigator(
        key: navigatorKey,
        observers: <NavigatorObserver>[_observer],
        onGenerateRoute: (_) => _destinationRoute(
          context: context,
          destinationId: 'music-flow',
          branchIndex: discoverBranchIndex,
          page: rootPage,
        ),
      ),
    );
  }

  void selectDestination({
    required BuildContext context,
    required String destinationId,
    required int branchIndex,
    required Widget page,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (destinationId == 'music-flow') {
      _observer.withoutForwardRecording(() {
        navigator.popUntil((route) => route.isFirst);
      });
      _observer.clearForwardHistory();
      _observer.refreshCurrent();
      return;
    }

    final destinationRouteName =
        '$_desktopDestinationRoutePrefix$destinationId';
    if (_observer.currentDestinationId == destinationId) {
      _observer.withoutForwardRecording(() {
        navigator.popUntil(
          (route) =>
              route.isFirst || route.settings.name == destinationRouteName,
        );
      });
      _observer.clearForwardHistory();
      _observer.refreshCurrent();
      return;
    }

    navigator.pushAndRemoveUntil<void>(
      _destinationRoute(
        context: context,
        destinationId: destinationId,
        branchIndex: branchIndex,
        page: page,
      ),
      (route) => route.isFirst,
    );
  }

  Future<bool> maybePop() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    return navigator.maybePop();
  }

  bool popCurrentAndDiscardForward() {
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return false;

    _observer.withoutForwardRecording(() => navigator.pop());
    _observer.clearForwardHistory();
    return true;
  }

  void goForward(BuildContext context) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    _observer.goForward(navigator: navigator, context: context);
  }

  Route<void> _destinationRoute({
    required BuildContext context,
    required String destinationId,
    required int branchIndex,
    required Widget page,
  }) {
    return EchoPageRoute<void>(
      context: context,
      settings: RouteSettings(
        name: '$_desktopDestinationRoutePrefix$destinationId',
        arguments: <String, Object>{
          'destinationId': destinationId,
          'branchIndex': branchIndex,
        },
      ),
      builder: (_) => page,
    );
  }
}

class _DesktopRouteSelection {
  const _DesktopRouteSelection({
    required this.destinationId,
    required this.branchIndex,
  });

  final String destinationId;
  final int branchIndex;
}

class _DesktopNavigationObserver extends NavigatorObserver {
  _DesktopNavigationObserver(this.onCurrentChanged);

  final DesktopNavigationStateChanged onCurrentChanged;
  final Map<Route<dynamic>, _DesktopRouteSelection> _selections =
      <Route<dynamic>, _DesktopRouteSelection>{};
  final List<EchoPageRoute<dynamic>> _forwardRoutes =
      <EchoPageRoute<dynamic>>[];
  Route<dynamic>? _currentRoute;
  bool _replayingForward = false;
  bool _discardForwardRecording = false;

  String? get currentDestinationId =>
      _currentRoute == null ? null : _selections[_currentRoute]?.destinationId;

  bool get canGoForward => _forwardRoutes.isNotEmpty;

  void clearForwardHistory() => _forwardRoutes.clear();

  void refreshCurrent() => _setCurrent(_currentRoute);

  void withoutForwardRecording(VoidCallback operation) {
    final previousValue = _discardForwardRecording;
    _discardForwardRecording = true;
    try {
      operation();
    } finally {
      _discardForwardRecording = previousValue;
    }
  }

  void goForward({
    required NavigatorState navigator,
    required BuildContext context,
  }) {
    if (_forwardRoutes.isEmpty) return;
    final route = _forwardRoutes.removeLast();
    _replayingForward = true;
    navigator.push<dynamic>(route.recreate(context));
  }

  _DesktopRouteSelection _selectionFor(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    final arguments = route.settings.arguments;
    if (arguments is Map<String, Object>) {
      final destinationId = arguments['destinationId'];
      final branchIndex = arguments['branchIndex'];
      if (destinationId is String && branchIndex is int) {
        return _DesktopRouteSelection(
          destinationId: destinationId,
          branchIndex: branchIndex,
        );
      }
    }
    return _selections[previousRoute] ??
        const _DesktopRouteSelection(
          destinationId: 'music-flow',
          branchIndex: discoverBranchIndex,
        );
  }

  void _setCurrent(Route<dynamic>? route) {
    _currentRoute = route;
    final selection = route == null
        ? null
        : _selections[route] ??
              const _DesktopRouteSelection(
                destinationId: 'music-flow',
                branchIndex: discoverBranchIndex,
              );
    onCurrentChanged(
      selection?.destinationId,
      selection?.branchIndex ?? discoverBranchIndex,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_replayingForward) clearForwardHistory();
    _replayingForward = false;
    _selections[route] = _selectionFor(route, previousRoute);
    _setCurrent(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_discardForwardRecording) {
      if (route is EchoPageRoute<dynamic>) {
        _forwardRoutes.add(route);
      } else {
        clearForwardHistory();
      }
    }
    _selections.remove(route);
    if (identical(_currentRoute, route)) _setCurrent(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _selections.remove(route);
    if (identical(_currentRoute, route)) _setCurrent(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldSelection = oldRoute == null ? null : _selections.remove(oldRoute);
    if (newRoute == null) return;
    final settings = newRoute.settings.arguments;
    if (settings is Map<String, Object> &&
        settings['destinationId'] is String &&
        settings['branchIndex'] is int) {
      _selections[newRoute] = _DesktopRouteSelection(
        destinationId: settings['destinationId']! as String,
        branchIndex: settings['branchIndex']! as int,
      );
    } else if (oldSelection != null) {
      _selections[newRoute] = oldSelection;
    }
    if (identical(_currentRoute, oldRoute)) _setCurrent(newRoute);
  }
}
