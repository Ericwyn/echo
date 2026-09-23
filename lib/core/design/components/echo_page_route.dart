import 'package:flutter/material.dart';

import '../echo_context.dart';

/// Echo's spatial page transition for imperative navigation.
///
/// The route resolves its durations before it is pushed, so a system request
/// for reduced motion becomes an actual jump cut instead of an invisible wait.
class EchoPageRoute<T> extends PageRouteBuilder<T> {
  factory EchoPageRoute({
    required BuildContext context,
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    PageStorageBucket? pageStorageBucket,
    Object? pageStorageKey,
  }) {
    return EchoPageRoute<T>._(
      context: context,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      pageStorageBucket: pageStorageBucket ?? PageStorageBucket(),
      pageStorageKey: pageStorageKey ?? Object(),
    );
  }

  // Explicit parameters keep the context-derived route setup in one initializer.
  // ignore: use_super_parameters
  EchoPageRoute._({
    required BuildContext context,
    required WidgetBuilder builder,
    required PageStorageBucket pageStorageBucket,
    required Object pageStorageKey,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : _builder = builder,
       _fullscreenDialog = fullscreenDialog,
       _pageStorageBucket = pageStorageBucket,
       _pageStorageKey = pageStorageKey,
       super(
         settings: settings,
         fullscreenDialog: fullscreenDialog,
         transitionDuration: context.echoMotion.resolve(
           context,
           context.echoMotion.scene,
         ),
         reverseTransitionDuration: context.echoMotion.resolve(
           context,
           context.echoMotion.state,
         ),
         pageBuilder: (context, animation, secondaryAnimation) {
           return PageStorage(
             bucket: pageStorageBucket,
             child: KeyedSubtree(
               key: PageStorageKey<Object>(pageStorageKey),
               child: builder(context),
             ),
           );
         },
         transitionsBuilder: _buildTransitions,
       );

  final WidgetBuilder _builder;
  final bool _fullscreenDialog;
  final PageStorageBucket _pageStorageBucket;
  final Object _pageStorageKey;

  /// Rebuilds this route when desktop history moves forward after a pop.
  EchoPageRoute<T> recreate(BuildContext context) {
    return EchoPageRoute<T>._(
      context: context,
      builder: _builder,
      settings: settings,
      fullscreenDialog: _fullscreenDialog,
      pageStorageBucket: _pageStorageBucket,
      pageStorageKey: _pageStorageKey,
    );
  }

  static Widget _buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.echoMotion.resolve(context, context.echoMotion.scene) ==
        Duration.zero) {
      return child;
    }

    final direction = Directionality.of(context) == TextDirection.ltr
        ? 1.0
        : -1.0;
    final curved = CurvedAnimation(
      parent: animation,
      curve: context.echoMotion.sceneCurve,
      reverseCurve: context.echoMotion.easeOut,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.86, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.035 * direction, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Declarative counterpart used by GoRouter page builders.
class EchoTransitionPage<T> extends Page<T> {
  const EchoTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return EchoPageRoute<T>(
      context: context,
      settings: this,
      builder: (context) => child,
    );
  }
}
