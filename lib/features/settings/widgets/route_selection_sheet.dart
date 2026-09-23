import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../data/models/server_address.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/library_provider.dart';

Future<void> showRouteSelectionSheet(
  BuildContext context, {
  VoidCallback? onClosed,
}) async {
  try {
    await showEchoBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _RouteSelectionSheet(),
    );
  } finally {
    onClosed?.call();
  }
}

class _RouteSelectionSheet extends ConsumerWidget {
  const _RouteSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLibraryId = ref.watch(
      authStateProvider.select((state) => state.currentLibrary?.id),
    );
    final libraries = ref.watch(librariesProvider);
    final activeAddress = ref.watch(activeAddressProvider);
    final addressPool = ref.read(addressPoolProvider);

    return EchoBottomSheet(
      title: '切换线路',
      subtitle: '手动锁定一条线路，或让 Echo 根据可用性和延迟自动选择。',
      constrainToAvailableHeight: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EchoButton.ghost(
            label: '重新检测延迟',
            leadingIcon: AppIcons.refresh,
            expand: true,
            onPressed: () => addressPool.probeAll(),
          ),
          SizedBox(height: context.echoSpacing.sm),
          Flexible(
            child: libraries.when(
              data: (items) {
                final library =
                    items
                        .where((item) => item.id == activeLibraryId)
                        .firstOrNull ??
                    items.firstOrNull;
                final poolAddresses = addressPool.addresses;
                final addresses =
                    List<ServerAddress>.from(
                      poolAddresses.isNotEmpty
                          ? poolAddresses
                          : library?.addresses ?? const <ServerAddress>[],
                    )..sort(
                      (first, second) =>
                          first.priority.compareTo(second.priority),
                    );

                if (addresses.isEmpty) {
                  return const SingleChildScrollView(
                    child: EchoEmptyState(
                      title: '没有可用线路',
                      description: '请先在设置中添加至少一个服务器地址。',
                      icon: AppIcons.route,
                      padding: EdgeInsets.all(24),
                    ),
                  );
                }

                final isAuto = !addresses.any(
                  (address) =>
                      address.isLocked && address.id == activeAddress?.id,
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: addresses.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return EchoActionRow(
                        icon: AppIcons.route,
                        title: '自动选择',
                        subtitle: isAuto
                            ? '当前已开启${activeAddress == null ? '' : ' · ${activeAddress.label}'}'
                            : '根据可用性和延迟选择线路',
                        selected: isAuto,
                        trailing: isAuto
                            ? Icon(
                                AppIcons.check,
                                color: context.echoColors.accent,
                              )
                            : null,
                        onPressed: () {
                          addressPool.setAutoMode();
                          Navigator.of(context).pop();
                        },
                      );
                    }
                    if (index == 1) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.echoSpacing.xs,
                        ),
                        child: const EchoDivider(),
                      );
                    }

                    final address = addresses[index - 2];
                    final selected =
                        activeAddress?.id == address.id && address.isLocked;
                    final status = _routeStatus(address);
                    return Padding(
                      padding: EdgeInsets.only(bottom: context.echoSpacing.xs),
                      child: EchoActionRow(
                        icon: AppIcons.signalTower,
                        title: address.label,
                        subtitle:
                            '${address.url}\n${status.label} · 延迟 ${address.lastLatencyMs == null ? '未知' : '${address.lastLatencyMs}ms'}',
                        selected: selected,
                        trailing: Semantics(
                          label: status.label,
                          child: Icon(
                            selected ? AppIcons.check : status.icon,
                            size: 20,
                            color: selected
                                ? context.echoColors.accent
                                : status.color(context),
                          ),
                        ),
                        onPressed: () {
                          addressPool.setManualMode(address);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const _RouteSelectionSkeleton(),
              error: (error, stackTrace) => SingleChildScrollView(
                child: EchoErrorState(
                  title: '无法读取线路',
                  description: '线路信息暂时不可用。请重试，或稍后在设置中检查地址。',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(librariesProvider),
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSelectionSkeleton extends StatelessWidget {
  const _RouteSelectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < 3; index++)
          Padding(
            padding: EdgeInsets.only(bottom: context.echoSpacing.md),
            child: Row(
              children: <Widget>[
                const EchoSkeleton.circle(),
                SizedBox(width: context.echoSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      EchoSkeleton.line(width: 140, height: 16),
                      SizedBox(height: 8),
                      EchoSkeleton.line(width: 196),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

_RouteStatus _routeStatus(ServerAddress address) {
  return switch (address.status) {
    ServerAddressStatus.ok => const _RouteStatus(
      label: '连接正常',
      icon: AppIcons.checkCircle,
      kind: _RouteStatusKind.connected,
    ),
    ServerAddressStatus.failed => const _RouteStatus(
      label: '连接失败',
      icon: AppIcons.error,
      kind: _RouteStatusKind.failed,
    ),
    ServerAddressStatus.unknown => const _RouteStatus(
      label: '等待检测',
      icon: AppIcons.help,
      kind: _RouteStatusKind.unknown,
    ),
  };
}

enum _RouteStatusKind { connected, failed, unknown }

class _RouteStatus {
  const _RouteStatus({
    required this.label,
    required this.icon,
    required this.kind,
  });

  final String label;
  final IconData icon;
  final _RouteStatusKind kind;

  Color color(BuildContext context) => switch (kind) {
    _RouteStatusKind.connected => context.echoColors.accent,
    _RouteStatusKind.failed => context.echoColors.error,
    _RouteStatusKind.unknown => context.echoColors.muted,
  };
}
