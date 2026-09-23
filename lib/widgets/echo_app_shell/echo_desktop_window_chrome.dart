import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design/echo_design.dart';
import '../../core/utils/logger.dart';

/// A Flutter-drawn Linux title bar shown on every route, including login and
/// first-run setup screens. The center title area can move the native window.
class EchoDesktopWindowChrome extends StatefulWidget {
  const EchoDesktopWindowChrome({super.key, required this.child});

  final Widget child;

  @override
  State<EchoDesktopWindowChrome> createState() =>
      _EchoDesktopWindowChromeState();
}

class _EchoDesktopWindowChromeState extends State<EchoDesktopWindowChrome>
    with WindowListener {
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

    return Column(
      children: <Widget>[
        DecoratedBox(
          key: const ValueKey<String>('echo-desktop-window-chrome'),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.controlBoundary)),
          ),
          child: SizedBox(
            height: 42,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: DragToMoveArea(
                    child: SizedBox(
                      height: double.infinity,
                      child: Center(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Echoes',
                            style: context.echoTypography.metadata.copyWith(
                              color: colors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
        Expanded(child: widget.child),
      ],
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
