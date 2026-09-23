import 'dart:async';

import 'package:echoes/core/design/echo_design.dart';
import 'package:echoes/data/models/music_library.dart';
import 'package:echoes/data/models/server_address.dart';
import 'package:echoes/features/settings/widgets/route_selection_sheet.dart';
import 'package:echoes/features/navigation/app_navigation_model.dart';
import 'package:echoes/providers/api_provider.dart';
import 'package:echoes/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../providers/offline_download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import 'echo_app_shell/echo_drawer.dart';

/// Echo's application drawer. [Scaffold] still supplies platform drawer
/// routing, focus, and back behavior; every visible surface is owned here.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, this.onReturnFocus});

  final VoidCallback? onReturnFocus;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _showLibraries = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final activeLibrary = authState.currentLibrary;
    final activeAddress = ref.watch(activeAddressProvider);

    return EchoDrawerFrame(
      header: EchoDrawerIdentityHeader(
        username: activeLibrary?.username ?? 'Guest',
        libraryName: activeLibrary?.name ?? '未选择',
        addressLabel: activeAddress?.label ?? '没有活动线路',
        connectionState: _connectionState(activeAddress),
        avatarUrl: resolveEchoDrawerAvatarUrl(activeLibrary),
        showingLibraries: _showLibraries,
        onToggleLibraries: () {
          setState(() {
            _showLibraries = !_showLibraries;
          });
        },
      ),
      child: _showLibraries
          ? _buildLibraryList(activeLibrary)
          : _buildNavigationList(activeAddress),
    );
  }

  Widget _buildLibraryList(MusicLibrary? activeLibrary) {
    final libraries = ref.watch(librariesProvider);

    return libraries.when(
      data: (items) {
        if (items.isEmpty) {
          return EchoEmptyState(
            title: '还没有音乐库',
            description: '添加一个 Navidrome、Subsonic 或 OpenSubsonic 音乐库后即可开始聆听。',
            icon: AppIcons.library,
            actionLabel: '添加音乐库',
            onAction: () => _closeDrawerAndPushLocation('/login?add=true'),
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('echo-drawer-libraries'),
          padding: EdgeInsets.symmetric(vertical: context.echoSpacing.xs),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: items.length + 2,
          itemBuilder: (context, index) {
            if (index < items.length) {
              final library = items[index];
              final isActive = library.id == activeLibrary?.id;
              return Padding(
                padding: EdgeInsets.only(bottom: context.echoSpacing.xs),
                child: EchoDrawerLibraryRow(
                  title: library.name,
                  subtitle: library.addresses.firstOrNull?.url ?? '未配置服务器地址',
                  selected: isActive,
                  onSelected: () {
                    if (!isActive) {
                      _switchLibrary(library);
                    }
                    setState(() {
                      _showLibraries = false;
                    });
                    Navigator.of(context).pop();
                  },
                  onEdit: () => _closeDrawerAndPushLocation(
                    '/library/edit/${library.id}',
                  ),
                ),
              );
            }

            if (index == items.length) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  context.echoSpacing.md,
                  context.echoSpacing.xxs,
                  context.echoSpacing.md,
                  context.echoSpacing.sm,
                ),
                child: const EchoDivider(),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: context.echoSpacing.xs),
              child: EchoActionRow(
                icon: AppIcons.add,
                title: '添加新音乐库',
                subtitle: '连接另一台服务器或另一个账户',
                onPressed: () => _closeDrawerAndPushLocation('/login?add=true'),
              ),
            );
          },
        );
      },
      loading: () => const _DrawerSkeletonList(),
      error: (error, stackTrace) => EchoErrorState(
        title: '无法读取音乐库',
        description: '音乐库列表暂时不可用。重试不会影响当前正在播放的内容。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(librariesProvider),
      ),
    );
  }

  Widget _buildNavigationList(ServerAddress? activeAddress) {
    final downloadSummary = ref.watch(offlineDownloadSummaryProvider);
    final routeLabel = activeAddress?.label.trim();
    final navigationItems = AppNavigationModel.drawerActions;
    final entries = <AppNavigationItem?>[];
    String? previousSection;
    for (final item in navigationItems) {
      final section = item.drawerSection;
      if (previousSection != null && section != previousSection) {
        entries.add(null);
      }
      entries.add(item);
      previousSection = section;
    }

    return ListView.builder(
      key: const PageStorageKey<String>('echo-drawer-navigation'),
      padding: EdgeInsets.symmetric(vertical: context.echoSpacing.xs),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        if (item == null) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              context.echoSpacing.md,
              context.echoSpacing.xxs,
              context.echoSpacing.md,
              context.echoSpacing.xs,
            ),
            child: const EchoDivider(),
          );
        }

        final String? subtitle = switch (item.id) {
          'route-selection' =>
            routeLabel == null || routeLabel.isEmpty ? '自动选择' : routeLabel,
          'offline' =>
            downloadSummary.total == 0
                ? '暂无任务'
                : '进行中 ${downloadSummary.active} · 完成 ${downloadSummary.completed} · '
                      '失败 ${downloadSummary.failed}',
          _ => null,
        };
        final VoidCallback onPressed = switch (item.id) {
          'route-selection' => _closeDrawerAndShowRouteSelection,
          _ => () => _closeDrawerAndPushPage((_) => item.pageBuilder!()),
        };

        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.echoSpacing.xs,
            0,
            context.echoSpacing.xs,
            context.echoSpacing.xs,
          ),
          child: EchoActionRow(
            icon: item.icon,
            title: item.drawerTitle,
            subtitle: subtitle,
            trailing: Icon(
              AppIcons.chevronRight,
              size: context.echoInteraction.smallIconSize,
              color: context.echoColors.muted,
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }

  Future<void> _switchLibrary(MusicLibrary library) async {
    final player = ref.read(playerProvider.notifier);
    await player.prepareForLibrarySwitch();
    final repository = ref.read(libraryRepositoryProvider);
    try {
      await repository.setActiveLibrary(library.id);
      ref.read(authStateProvider.notifier).switchLibrary(library);

      ref.invalidate(playerProvider);
      ref.invalidate(randomSongsProvider);
      ref.invalidate(recentAlbumsProvider);
      ref.invalidate(frequentAlbumsProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(starredProvider);
    } catch (_) {
      await player.cancelLibrarySwitchPreparation();
      rethrow;
    }
  }

  void _closeDrawerAndPushPage(WidgetBuilder builder) {
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.push(
        EchoPageRoute<void>(context: navigator.context, builder: builder),
      );
    });
  }

  void _closeDrawerAndPushLocation(String location) {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      router.push(location);
    });
  }

  void _closeDrawerAndShowRouteSelection() {
    final navigator = Navigator.of(context);
    final onReturnFocus = widget.onReturnFocus;
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      unawaited(
        showRouteSelectionSheet(navigator.context, onClosed: onReturnFocus),
      );
    });
  }
}

@visibleForTesting
String? resolveEchoDrawerAvatarUrl(MusicLibrary? library) {
  if (library == null) return null;
  final raw = library.extensions['avatarUrl'];
  if (raw is! String || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || (!uri.hasScheme && !uri.hasAbsolutePath)) return null;
  return raw.trim();
}

EchoDrawerConnectionState _connectionState(ServerAddress? address) {
  if (address == null) return EchoDrawerConnectionState.disconnected;
  return switch (address.status) {
    ServerAddressStatus.ok => EchoDrawerConnectionState.connected,
    ServerAddressStatus.failed => EchoDrawerConnectionState.failed,
    ServerAddressStatus.unknown => EchoDrawerConnectionState.unknown,
  };
}

class _DrawerSkeletonList extends StatelessWidget {
  const _DrawerSkeletonList({this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.echoSpacing.md,
        vertical: context.echoSpacing.sm,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.echoSpacing.md),
          child: Row(
            children: <Widget>[
              const EchoSkeleton.circle(),
              SizedBox(width: context.echoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    EchoSkeleton.line(
                      width: index.isEven ? 140 : 112,
                      height: 16,
                    ),
                    SizedBox(height: context.echoSpacing.xs),
                    const EchoSkeleton.line(width: 196),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
