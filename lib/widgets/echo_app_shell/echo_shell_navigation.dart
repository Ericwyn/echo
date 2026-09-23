import 'package:flutter/material.dart';

import '../../core/design/echo_design.dart';

@immutable
class EchoShellDestination {
  const EchoShellDestination({
    required this.branchIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final int branchIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

@immutable
class EchoDesktopSidebarAction {
  const EchoDesktopSidebarAction({
    required this.id,
    required this.section,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String id;
  final String section;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
}

class EchoCompactNavigation extends StatelessWidget {
  const EchoCompactNavigation({
    super.key,
    required this.destinations,
    required this.selectedBranchIndex,
    required this.onDestinationSelected,
  });

  final List<EchoShellDestination> destinations;
  final int selectedBranchIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final spacing = context.echoSpacing;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '主导航',
      child: ColoredBox(
        key: const ValueKey<String>('echo-compact-navigation'),
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xxs),
              child: Row(
                children: <Widget>[
                  for (final destination in destinations)
                    Expanded(
                      child: _CompactDestination(
                        destination: destination,
                        selected:
                            destination.branchIndex == selectedBranchIndex,
                        onPressed: () =>
                            onDestinationSelected(destination.branchIndex),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EchoMediumNavigationRail extends StatelessWidget {
  const EchoMediumNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedBranchIndex,
    required this.onDestinationSelected,
    required this.onOpenDrawer,
  });

  final List<EchoShellDestination> destinations;
  final int selectedBranchIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final spacing = context.echoSpacing;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '主导航',
      child: ColoredBox(
        key: const ValueKey<String>('echo-medium-navigation'),
        color: context.echoColors.surface,
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: 96,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(spacing.xs),
                  child: EchoIconButton(
                    icon: AppIcons.menu,
                    label: '打开应用菜单',
                    onPressed: onOpenDrawer,
                  ),
                ),
                EchoDivider(inset: spacing.sm, endInset: spacing.sm),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: spacing.sm),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: spacing.xxs),
                        child: _RailDestination(
                          destination: destination,
                          selected:
                              destination.branchIndex == selectedBranchIndex,
                          onPressed: () =>
                              onDestinationSelected(destination.branchIndex),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EchoExpandedNavigationSidebar extends StatelessWidget {
  const EchoExpandedNavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedBranchIndex,
    required this.onDestinationSelected,
    this.actions = const <EchoDesktopSidebarAction>[],
    this.accountLabel = '账户',
    this.accountSubtitle = '',
    this.playbackSlotHeight,
  });

  final List<EchoShellDestination> destinations;
  final int selectedBranchIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<EchoDesktopSidebarAction> actions;
  final String accountLabel;
  final String accountSubtitle;
  final double? playbackSlotHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.echoSpacing;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '主导航',
      child: ColoredBox(
        key: const ValueKey<String>('echo-expanded-navigation'),
        color: context.echoColors.surface,
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: 232,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.sm,
                    spacing.xs,
                    spacing.md,
                    spacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.echoColors.accent.withValues(
                            alpha: 0.13,
                          ),
                          borderRadius: context.echoRadii.control,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.xs),
                          child: Icon(
                            AppIcons.musicFlowFilled,
                            size: 20,
                            color: context.echoColors.accent,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Echo',
                            style: context.echoTypography.title,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                EchoDivider(inset: spacing.md, endInset: spacing.md),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.md,
                    ),
                    children: <Widget>[
                      if (actions.isEmpty) ...<Widget>[
                        _SidebarSectionLabel(label: '浏览'),
                        for (final destination in destinations)
                          Padding(
                            padding: EdgeInsets.only(bottom: spacing.xxs),
                            child: _SidebarDestination(
                              destination: destination,
                              selected:
                                  destination.branchIndex ==
                                  selectedBranchIndex,
                              onPressed: () => onDestinationSelected(
                                destination.branchIndex,
                              ),
                            ),
                          ),
                      ],
                      for (
                        var index = 0;
                        index < actions.length;
                        index++
                      ) ...<Widget>[
                        if (index == 0 ||
                            actions[index].section !=
                                actions[index - 1].section)
                          _SidebarSectionLabel(
                            label: actions[index].section,
                            topPadding: spacing.md,
                          ),
                        Padding(
                          padding: EdgeInsets.only(bottom: spacing.xxs),
                          child: _DesktopSidebarActionRow(
                            action: actions[index],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (playbackSlotHeight == null) ...<Widget>[
                  EchoDivider(inset: spacing.md, endInset: spacing.md),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.sm,
                      spacing.xs,
                      spacing.sm,
                      spacing.xs,
                    ),
                    child: _DesktopAccountIdentity(
                      accountLabel: accountLabel,
                      accountSubtitle: accountSubtitle,
                    ),
                  ),
                ] else
                  SizedBox(
                    key: const ValueKey<String>('echo-desktop-account-footer'),
                    height: playbackSlotHeight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: spacing.xs,
                        bottom: spacing.xxs,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: context.echoColors.divider),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          spacing.sm,
                          spacing.xs,
                          spacing.sm,
                          spacing.xs,
                        ),
                        child: _DesktopAccountIdentity(
                          accountLabel: accountLabel,
                          accountSubtitle: accountSubtitle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label, this.topPadding = 0});

  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.echoSpacing.sm,
        topPadding,
        context.echoSpacing.xs,
        context.echoSpacing.xs,
      ),
      child: Text(
        label,
        style: context.echoTypography.label.copyWith(
          fontSize: 14,
          color: context.echoColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DesktopSidebarActionRow extends StatelessWidget {
  const _DesktopSidebarActionRow({required this.action});

  final EchoDesktopSidebarAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final selected = action.selected;
    final foreground = selected ? colors.accent : colors.ink;
    return EchoPressable(
      key: ValueKey<String>('echo-desktop-sidebar-${action.id}'),
      semanticLabel: action.label,
      selected: selected,
      onPressed: action.onPressed,
      minimumSize: const Size(double.infinity, 48),
      borderRadius: context.echoRadii.control,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: 0.1) : null,
          borderRadius: context.echoRadii.control,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.echoSpacing.md,
            context.echoSpacing.xs,
            context.echoSpacing.sm,
            context.echoSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                action.icon,
                size: context.echoInteraction.smallIconSize,
                color: foreground,
              ),
              SizedBox(width: context.echoSpacing.sm),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.echoTypography.body.copyWith(
                    fontSize: 15,
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDestination extends StatelessWidget {
  const _CompactDestination({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final EchoShellDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final spacing = context.echoSpacing;
    final foreground = selected ? colors.accent : colors.muted;

    return EchoPressable(
      semanticLabel: destination.label,
      selected: selected,
      onPressed: onPressed,
      enableHaptics: true,
      minimumSize: const Size(double.infinity, 64),
      borderRadius: context.echoRadii.detail,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: _SelectionMarker(
              markerKey: ValueKey<String>(
                'echo-compact-selection-indicator-'
                '${destination.branchIndex}',
              ),
              selected: selected,
              axis: Axis.horizontal,
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xxs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _AnimatedDestinationIcon(
                    icon: selected
                        ? destination.selectedIcon
                        : destination.icon,
                    color: foreground,
                    size: context.echoInteraction.smallIconSize,
                  ),
                  SizedBox(height: spacing.xxs),
                  _AnimatedDestinationLabel(
                    label: destination.label,
                    color: foreground,
                    selected: selected,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final EchoShellDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final spacing = context.echoSpacing;
    final foreground = selected ? colors.accent : colors.muted;

    return EchoPressable(
      semanticLabel: destination.label,
      selected: selected,
      onPressed: onPressed,
      enableHaptics: true,
      minimumSize: const Size(double.infinity, 80),
      borderRadius: context.echoRadii.detail,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          spacing.xxs,
          spacing.xs,
          spacing.xxs,
          spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            _SelectionMarker(
              markerKey: ValueKey<String>(
                'echo-medium-selection-indicator-'
                '${destination.branchIndex}',
              ),
              selected: selected,
              axis: Axis.vertical,
            ),
            SizedBox(width: spacing.xxs),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _AnimatedDestinationIcon(
                    icon: selected
                        ? destination.selectedIcon
                        : destination.icon,
                    color: foreground,
                    size: context.echoInteraction.iconSize,
                  ),
                  SizedBox(height: spacing.xxs),
                  _AnimatedDestinationLabel(
                    label: destination.label,
                    color: foreground,
                    selected: selected,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final EchoShellDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.echoColors;
    final spacing = context.echoSpacing;
    final foreground = selected ? colors.accent : colors.muted;

    return EchoPressable(
      semanticLabel: destination.label,
      selected: selected,
      onPressed: onPressed,
      enableHaptics: true,
      minimumSize: const Size(double.infinity, 64),
      borderRadius: context.echoRadii.detail,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          spacing.xxs,
          spacing.xs,
          spacing.xs,
          spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            _SelectionMarker(
              markerKey: ValueKey<String>(
                'echo-expanded-selection-indicator-'
                '${destination.branchIndex}',
              ),
              selected: selected,
              axis: Axis.vertical,
            ),
            SizedBox(width: spacing.xs),
            SizedBox.square(
              dimension: context.echoInteraction.minimumTouchTarget,
              child: Center(
                child: _AnimatedDestinationIcon(
                  icon: selected ? destination.selectedIcon : destination.icon,
                  color: foreground,
                  size: context.echoInteraction.iconSize,
                ),
              ),
            ),
            SizedBox(width: spacing.xxs),
            Expanded(
              child: _AnimatedDestinationLabel(
                label: destination.label,
                color: foreground,
                selected: selected,
                style: context.echoTypography.body.copyWith(fontSize: 15),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopAccountIdentity extends StatelessWidget {
  const _DesktopAccountIdentity({
    required this.accountLabel,
    required this.accountSubtitle,
  });

  final String accountLabel;
  final String accountSubtitle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.echoSpacing;
    return Semantics(
      label:
          '当前账户 $accountLabel${accountSubtitle.isEmpty ? '' : '，$accountSubtitle'}',
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            children: <Widget>[
              Icon(
                AppIcons.profile,
                size: context.echoInteraction.iconSize,
                color: context.echoColors.accent,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.echoTypography.label.copyWith(
                        fontSize: 14,
                        color: context.echoColors.ink,
                      ),
                    ),
                    if (accountSubtitle.isNotEmpty)
                      Text(
                        accountSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.echoTypography.metadata.copyWith(
                          fontSize: 13,
                          color: context.echoColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMarker extends StatelessWidget {
  const _SelectionMarker({
    required this.markerKey,
    required this.selected,
    required this.axis,
  });

  final Key markerKey;
  final bool selected;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final motion = context.echoMotion;
    final duration = motion.resolve(context, motion.state);
    final horizontal = axis == Axis.horizontal;

    return SizedBox(
      width: horizontal ? 24 : 3,
      height: horizontal ? 3 : 28,
      child: AnimatedOpacity(
        key: markerKey,
        duration: duration,
        curve: motion.easeOut,
        opacity: selected ? 1 : 0,
        child: AnimatedScale(
          duration: duration,
          curve: motion.easeOut,
          scale: selected ? 1 : 0.68,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.echoColors.accent,
              borderRadius: context.echoRadii.detail,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDestinationIcon extends StatelessWidget {
  const _AnimatedDestinationIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final motion = context.echoMotion;
    return AnimatedSwitcher(
      duration: motion.resolve(context, motion.state),
      switchInCurve: motion.easeOut,
      switchOutCurve: motion.easeOut,
      child: Icon(
        icon,
        key: ValueKey<String>(
          '${icon.codePoint}-${icon.fontFamily}-${icon.fontPackage}',
        ),
        size: size,
        color: color,
      ),
    );
  }
}

class _AnimatedDestinationLabel extends StatelessWidget {
  const _AnimatedDestinationLabel({
    required this.label,
    required this.color,
    required this.selected,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
  });

  final String label;
  final Color color;
  final bool selected;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final motion = context.echoMotion;
    return AnimatedDefaultTextStyle(
      duration: motion.resolve(context, motion.state),
      curve: motion.easeOut,
      style: (style ?? context.echoTypography.label).copyWith(
        color: color,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      child: Text(
        label,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}
