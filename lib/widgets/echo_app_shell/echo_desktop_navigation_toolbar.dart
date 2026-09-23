import 'package:flutter/material.dart';

import '../../core/design/echo_design.dart';

/// Browser-style back/forward controls for the expanded desktop shell.
class EchoDesktopNavigationToolbar extends StatelessWidget {
  const EchoDesktopNavigationToolbar({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.echoSpacing;
    final colors = context.echoColors;

    return DecoratedBox(
      key: const ValueKey<String>('echo-desktop-navigation-toolbar'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: SizedBox(
        height: echoDesktopNavigationHeaderHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            children: <Widget>[
              EchoIconButton(
                key: const ValueKey<String>('echo-desktop-back'),
                icon: AppIcons.back,
                label: '返回',
                onPressed: canGoBack ? onBack : null,
              ),
              EchoIconButton(
                key: const ValueKey<String>('echo-desktop-forward'),
                icon: AppIcons.forward,
                label: '前进',
                onPressed: canGoForward ? onForward : null,
              ),
              const Spacer(),
              EchoIconButton(
                key: const ValueKey<String>('echo-desktop-search'),
                icon: AppIcons.search,
                label: '搜索音乐库',
                onPressed: onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
