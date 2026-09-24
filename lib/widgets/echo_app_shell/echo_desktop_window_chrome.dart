import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design/echo_design.dart';
import '../../core/utils/logger.dart';

/// Navigation supplied by the expanded desktop shell to the Linux window bar.
@immutable
class EchoDesktopChromeNavigation {
  const EchoDesktopChromeNavigation({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onSearch,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onSearch;
}

/// Keeps navigation in the same bar as the native window actions without
/// coupling the window wrapper to the authenticated route tree.
class EchoDesktopWindowChromeController
    extends ValueNotifier<EchoDesktopChromeNavigation?> {
  EchoDesktopWindowChromeController() : super(null);

  Object? _owner;

  void showNavigation(Object owner, EchoDesktopChromeNavigation navigation) {
    final current = value;
    if (_owner == owner &&
        current != null &&
        current.canGoBack == navigation.canGoBack &&
        current.canGoForward == navigation.canGoForward &&
        current.onBack == navigation.onBack &&
        current.onForward == navigation.onForward &&
        current.onSearch == navigation.onSearch) {
      return;
    }
    _owner = owner;
    value = navigation;
  }

  void clearNavigation(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    value = null;
  }
}

class EchoDesktopWindowChromeScope extends InheritedWidget {
  const EchoDesktopWindowChromeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final EchoDesktopWindowChromeController controller;

  static EchoDesktopWindowChromeController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<EchoDesktopWindowChromeScope>()
          ?.controller;

  @override
  bool updateShouldNotify(EchoDesktopWindowChromeScope oldWidget) =>
      controller != oldWidget.controller;
}

/// A Flutter-drawn Linux title bar shown on every route, including login and
/// first-run setup screens. Empty title areas can move the native window.
class EchoDesktopWindowChrome extends StatefulWidget {
  const EchoDesktopWindowChrome({super.key, required this.child});

  final Widget child;

  @override
  State<EchoDesktopWindowChrome> createState() =>
      _EchoDesktopWindowChromeState();
}

class _EchoDesktopWindowChromeState extends State<EchoDesktopWindowChrome>
    with WindowListener {
  final _navigationController = EchoDesktopWindowChromeController();
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_refreshMaximizedState());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _navigationController.dispose();
    super.dispose();
  }

  Future<void> _refreshMaximizedState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _isMaximized) {
        setState(() => _isMaximized = maximized);
      }
    } catch (error) {
      Logger.debugWithTag('DESKTOP', 'cannot read maximized state: $error');
    }
  }

  void _runWindowAction(String actionName, Future<void> Function() action) {
    unawaited(() async {
      try {
        await action();
      } catch (error) {
        Logger.warnWithTag('DESKTOP', 'window $actionName failed', error);
      }
    }());
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;

    return EchoDesktopWindowChromeScope(
      controller: _navigationController,
      child: Column(
        children: <Widget>[
          ValueListenableBuilder<EchoDesktopChromeNavigation?>(
            valueListenable: _navigationController,
            builder: (context, navigation, _) => DecoratedBox(
              key: const ValueKey<String>('echo-desktop-window-chrome'),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: SizedBox(
                height: echoDesktopNavigationHeaderHeight,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 232,
                      height: double.infinity,
                      child: DragToMoveArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: <Widget>[
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.13),
                                  borderRadius: context.echoRadii.control,
                                ),
                                child: SizedBox.square(
                                  dimension: 34,
                                  child: Icon(
                                    AppIcons.musicFlowFilled,
                                    size: 20,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Semantics(
                                header: true,
                                child: Text(
                                  'Echo',
                                  style: context.echoTypography.title,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (navigation != null) ...<Widget>[
                      EchoIconButton(
                        key: const ValueKey<String>('echo-desktop-back'),
                        icon: AppIcons.back,
                        label: '返回',
                        onPressed: navigation.canGoBack
                            ? navigation.onBack
                            : null,
                      ),
                      EchoIconButton(
                        key: const ValueKey<String>('echo-desktop-forward'),
                        icon: AppIcons.forward,
                        label: '前进',
                        onPressed: navigation.canGoForward
                            ? navigation.onForward
                            : null,
                      ),
                    ],
                    Expanded(
                      child: DragToMoveArea(
                        child: const SizedBox(height: double.infinity),
                      ),
                    ),
                    if (navigation != null)
                      EchoIconButton(
                        key: const ValueKey<String>('echo-desktop-search'),
                        icon: AppIcons.search,
                        label: '搜索音乐库',
                        onPressed: navigation.onSearch,
                      ),
                    _DesktopWindowButton(
                      key: const ValueKey<String>('echo-window-minimize'),
                      label: '最小化窗口',
                      icon: Icons.remove_rounded,
                      onPressed: () =>
                          _runWindowAction('minimize', windowManager.minimize),
                    ),
                    _DesktopWindowButton(
                      key: const ValueKey<String>('echo-window-maximize'),
                      label: _isMaximized ? '还原窗口' : '最大化窗口',
                      icon: _isMaximized
                          ? Icons.filter_none_rounded
                          : Icons.crop_square_rounded,
                      onPressed: () => _runWindowAction(
                        _isMaximized ? 'unmaximize' : 'maximize',
                        _toggleMaximize,
                      ),
                    ),
                    _DesktopWindowButton(
                      key: const ValueKey<String>('echo-window-close'),
                      label: '关闭窗口',
                      icon: Icons.close_rounded,
                      isClose: true,
                      onPressed: () =>
                          _runWindowAction('close', windowManager.close),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _DesktopWindowButton extends StatelessWidget {
  const _DesktopWindowButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: context.echoRadii.control,
            hoverColor: isClose
                ? colors.error.withValues(alpha: 0.14)
                : colors.raised,
            child: SizedBox(
              width: 40,
              height: 38,
              child: Icon(icon, size: 18, color: colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
