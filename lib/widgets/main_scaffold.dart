import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/echo_design.dart';
import '../core/network/connectivity_monitor.dart';
import '../core/utils/logger.dart';
import '../data/models/server_address.dart';
import '../features/discover/pages/discover_page.dart';
import '../features/explore/pages/explore_page.dart';
import '../features/download/pages/download_manager_page.dart';
import '../features/library/pages/album_list_page.dart';
import '../features/library/pages/artist_list_page.dart';
import '../features/library/pages/library_page.dart';
import '../features/library/pages/song_list_page.dart';
import '../features/library/pages/starred_page.dart';
import '../features/offline/pages/offline_download_status_page.dart';
import '../features/player/widgets/mini_player.dart';
import '../features/player/pages/desktop_player_workspace.dart';
import '../features/player/widgets/desktop_playback_bar.dart';
import '../features/settings/pages/app_settings_page.dart';
import '../features/discover/pages/search_page.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/offline_download_provider.dart';
import '../providers/player_provider.dart';
import 'app_drawer.dart';
import 'echo_app_shell/echo_app_shell.dart';
import 'echo_app_shell/desktop_navigation_strategy.dart';
import 'echo_app_shell/echo_desktop_navigation_toolbar.dart';
import 'echo_app_shell/echo_network_status_bar.dart';
import 'echo_app_shell/echo_shell_navigation.dart';

// GlobalKey used to access Scaffold state (e.g. opening drawer).
final scaffoldKey = GlobalKey<ScaffoldState>();
FocusNode? _appDrawerTriggerFocus;

/// Opens the application drawer while retaining the keyboard focus origin.
///
/// Compact pages and the wide shell share this entry point so a drawer-owned
/// overlay can return focus to the exact menu control that launched it.
void openEchoAppDrawer() {
  final currentFocus = FocusManager.instance.primaryFocus;
  if (currentFocus != null &&
      currentFocus.context != null &&
      currentFocus.canRequestFocus) {
    _appDrawerTriggerFocus = currentFocus;
  }
  scaffoldKey.currentState?.openDrawer();
}

/// Page headers own the drawer trigger only in the compact shell.
///
/// Medium and expanded layouts expose the same action from their persistent
/// navigation surface, so retaining the page-level button would create a
/// duplicate control and a confusing accessibility traversal order.
bool shouldShowPageDrawerTrigger(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return context.echoBreakpoints.classify(width) == EchoWindowClass.compact;
}

void _restoreEchoAppDrawerFocus() {
  final triggerFocus = _appDrawerTriggerFocus;
  _appDrawerTriggerFocus = null;
  if (triggerFocus == null ||
      triggerFocus.context == null ||
      !triggerFocus.canRequestFocus) {
    return;
  }
  triggerFocus.requestFocus();
}

enum EchoBackAction {
  closeDrawer,
  popRootNavigator,
  popBranchNavigator,
  switchToDiscover,
  moveAppToBackground,
}

class _ToggleDesktopPlaybackIntent extends Intent {
  const _ToggleDesktopPlaybackIntent();
}

class _PreviousDesktopTrackIntent extends Intent {
  const _PreviousDesktopTrackIntent();
}

class _NextDesktopTrackIntent extends Intent {
  const _NextDesktopTrackIntent();
}

class _OpenDesktopSearchIntent extends Intent {
  const _OpenDesktopSearchIntent();
}

class _DesktopEscapeIntent extends Intent {
  const _DesktopEscapeIntent();
}

class _DesktopCallbackAction<T extends Intent> extends ContextAction<T> {
  _DesktopCallbackAction({required this.callback, this.enabled});

  final VoidCallback callback;
  final bool Function()? enabled;

  @override
  bool isEnabled(T intent, [BuildContext? context]) => enabled?.call() ?? true;

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    callback();
    return null;
  }
}

bool _isTextOrValueControlFocused() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext is! Element) return false;

  Element? element = focusContext;
  while (element != null) {
    final widget = element.widget;
    if (widget is EditableText ||
        widget is TextField ||
        widget is Slider ||
        widget is RangeSlider ||
        widget is DropdownButton ||
        widget is PopupMenuButton) {
      return true;
    }
    Element? parent;
    element.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false;
    });
    element = parent;
  }
  return false;
}

@visibleForTesting
EchoBackAction resolveEchoBackAction({
  required bool drawerOpen,
  required bool rootCanPop,
  required bool branchCanPop,
  required int currentBranchIndex,
}) {
  if (drawerOpen) return EchoBackAction.closeDrawer;
  if (rootCanPop) return EchoBackAction.popRootNavigator;
  if (branchCanPop) return EchoBackAction.popBranchNavigator;
  if (currentBranchIndex != discoverBranchIndex) {
    return EchoBackAction.switchToDiscover;
  }
  return EchoBackAction.moveAppToBackground;
}

const EchoShellDestination _discoverDestination = EchoShellDestination(
  branchIndex: discoverBranchIndex,
  label: '音乐流',
  icon: AppIcons.musicFlow,
  selectedIcon: AppIcons.musicFlowFilled,
);

const EchoShellDestination _exploreDestination = EchoShellDestination(
  branchIndex: exploreBranchIndex,
  label: '探索',
  icon: AppIcons.discover,
  selectedIcon: AppIcons.discoverFilled,
);

const EchoShellDestination _libraryDestination = EchoShellDestination(
  branchIndex: libraryBranchIndex,
  label: '我的',
  icon: AppIcons.personal,
  selectedIcon: AppIcons.personalFilled,
);

const EchoShellDestination _catalogDestination = EchoShellDestination(
  branchIndex: catalogBranchIndex,
  label: '曲库',
  icon: AppIcons.catalog,
  selectedIcon: AppIcons.catalogFilled,
);

@visibleForTesting
List<EchoShellDestination> echoMainDestinations({
  required bool showExploreTab,
}) {
  return <EchoShellDestination>[
    _discoverDestination,
    if (showExploreTab) _exploreDestination,
    _libraryDestination,
    _catalogDestination,
  ];
}

class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  const MainScaffold({
    super.key,
    required this.navigationShell,
    required this.branchNavigatorKeys,
    this.drawerOverride,
    this.miniPlayerOverride,
    this.showMiniPlayerOverride,
    this.showExploreTabOverride,
    this.networkStatusOverride,
    this.desktopRootOverride,
    this.desktopPageBuilderOverride,
  });

  @visibleForTesting
  final Widget? drawerOverride;

  @visibleForTesting
  final Widget? miniPlayerOverride;

  @visibleForTesting
  final bool? showMiniPlayerOverride;

  @visibleForTesting
  final bool? showExploreTabOverride;

  @visibleForTesting
  final EchoNetworkStatus? networkStatusOverride;

  @visibleForTesting
  final Widget? desktopRootOverride;

  @visibleForTesting
  final Widget Function(String destinationId)? desktopPageBuilderOverride;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  static const _logTag = 'BACK';
  static const MethodChannel _appLifecycleChannel = MethodChannel(
    'com.az1n.echoes/app_lifecycle',
  );
  int? _lastSyncedBranchIndex;
  EchoWindowClass? _lastWindowClass;
  bool _branchFallbackScheduled = false;
  bool _desktopNavigatorMounted = false;
  StreamSubscription<NetworkType>? _networkTypeSubscription;
  Timer? _initialNetworkStateTimer;
  NetworkType? _observedNetworkType;
  bool _showDesktopPlayerWorkspace = false;
  DesktopPlayerPanel _desktopPlayerPanel = DesktopPlayerPanel.lyrics;
  String? _desktopSelectedActionId;
  int _desktopRouteSelectionRevision = 0;
  bool _desktopCanGoBack = false;
  bool _desktopCanGoForward = false;
  late final DesktopNavigationStrategy _desktopNavigationStrategy;

  @override
  void initState() {
    super.initState();
    _desktopNavigationStrategy = DesktopNavigationStrategy(
      onChanged: _handleDesktopRouteChanged,
    );
    _scheduleVisibleBranchSync();
    if (widget.networkStatusOverride == null) {
      _startNetworkObservation();
    }
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleVisibleBranchSync();
    if (oldWidget.networkStatusOverride != widget.networkStatusOverride) {
      if (widget.networkStatusOverride == null) {
        _startNetworkObservation();
      } else {
        _stopNetworkObservation();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final windowClass = context.echoBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    if (_lastWindowClass != windowClass) {
      _lastWindowClass = windowClass;
      _lastSyncedBranchIndex = null;
    }
    if (windowClass == EchoWindowClass.expanded) {
      _desktopNavigatorMounted = true;
    }
    _scheduleVisibleBranchSync();
  }

  @override
  void dispose() {
    _stopNetworkObservation();
    super.dispose();
  }

  void _startNetworkObservation() {
    _stopNetworkObservation();
    final monitor = ref.read(connectivityMonitorProvider);
    _networkTypeSubscription = monitor.networkTypeStream.listen((networkType) {
      _initialNetworkStateTimer?.cancel();
      if (!mounted || _observedNetworkType == networkType) return;
      setState(() {
        _observedNetworkType = networkType;
      });
    });
    _initialNetworkStateTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _observedNetworkType != null) return;
      setState(() {
        _observedNetworkType = monitor.currentNetworkType;
      });
    });
  }

  void _stopNetworkObservation() {
    _initialNetworkStateTimer?.cancel();
    _initialNetworkStateTimer = null;
    _networkTypeSubscription?.cancel();
    _networkTypeSubscription = null;
    _observedNetworkType = null;
  }

  EchoNetworkStatus _resolveNetworkStatus({
    required bool activeAddressIsHealthy,
  }) {
    final networkType = _observedNetworkType;
    if (networkType == null) return EchoNetworkStatus.online;
    if (networkType == NetworkType.none) return EchoNetworkStatus.offline;
    if (!activeAddressIsHealthy) return EchoNetworkStatus.weak;
    return EchoNetworkStatus.online;
  }

  void _scheduleVisibleBranchSync() {
    if (_lastWindowClass == EchoWindowClass.expanded) return;
    final currentIndex = widget.navigationShell.currentIndex;
    if (_lastSyncedBranchIndex == currentIndex) {
      return;
    }
    _lastSyncedBranchIndex = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_lastWindowClass == EchoWindowClass.expanded) return;
      if (widget.navigationShell.currentIndex != currentIndex) return;
      _syncVisibleBranch(currentIndex);
    });
  }

  void _syncVisibleBranch(int branchIndex) {
    _lastSyncedBranchIndex = branchIndex;
    ref.read(currentVisibleBranchIndexProvider.notifier).state = branchIndex;
  }

  void _goToBranch(int branchIndex, {bool initialLocation = false}) {
    _syncVisibleBranch(branchIndex);
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: initialLocation,
    );
  }

  void _handleDesktopRouteChanged(String? destinationId, int branchIndex) {
    final revision = ++_desktopRouteSelectionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _desktopRouteSelectionRevision) return;
      ref.read(currentVisibleBranchIndexProvider.notifier).state = branchIndex;
      final canGoBack = _desktopNavigationStrategy.canGoBack;
      final canGoForward = _desktopNavigationStrategy.canGoForward;
      if (_desktopSelectedActionId == destinationId &&
          _desktopCanGoBack == canGoBack &&
          _desktopCanGoForward == canGoForward) {
        return;
      }
      setState(() {
        _desktopSelectedActionId = destinationId;
        _desktopCanGoBack = canGoBack;
        _desktopCanGoForward = canGoForward;
      });
    });
  }

  void _navigateDesktopForward() {
    _desktopNavigationStrategy.goForward(context);
  }

  Widget _withDesktopShortcuts(Widget child) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space):
            _ToggleDesktopPlaybackIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _OpenDesktopSearchIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _PreviousDesktopTrackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _NextDesktopTrackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DesktopEscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleDesktopPlaybackIntent:
              _DesktopCallbackAction<_ToggleDesktopPlaybackIntent>(
                enabled: () => !_isTextOrValueControlFocused(),
                callback: () => unawaited(
                  ref.read(playerProvider.notifier).togglePlayPause(),
                ),
              ),
          _PreviousDesktopTrackIntent:
              _DesktopCallbackAction<_PreviousDesktopTrackIntent>(
                enabled: () => !_isTextOrValueControlFocused(),
                callback: () =>
                    unawaited(ref.read(playerProvider.notifier).previous()),
              ),
          _NextDesktopTrackIntent:
              _DesktopCallbackAction<_NextDesktopTrackIntent>(
                enabled: () => !_isTextOrValueControlFocused(),
                callback: () =>
                    unawaited(ref.read(playerProvider.notifier).next()),
              ),
          _OpenDesktopSearchIntent:
              _DesktopCallbackAction<_OpenDesktopSearchIntent>(
                enabled: () => !_isTextOrValueControlFocused(),
                callback: () => _selectDesktopDestination(
                  destinationId: 'search',
                  branchIndex: discoverBranchIndex,
                  page: const SearchPage(),
                ),
              ),
          _DesktopEscapeIntent: _DesktopCallbackAction<_DesktopEscapeIntent>(
            callback: () => unawaited(_handleDesktopEscape()),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  Future<void> _handleDesktopEscape() async {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final routeContext = focusContext ?? context;
    if (ModalRoute.of(routeContext) is PopupRoute) {
      if (await Navigator.of(routeContext).maybePop()) return;
    }

    final scaffold = scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) {
      scaffold?.closeDrawer();
      return;
    }
    if (_showDesktopPlayerWorkspace) {
      setState(() => _showDesktopPlayerWorkspace = false);
      return;
    }
    if (_desktopNavigationStrategy.canGoBack) {
      await _desktopNavigationStrategy.maybePop();
    }
  }

  Widget _desktopPage(String destinationId, Widget page) {
    return widget.desktopPageBuilderOverride?.call(destinationId) ?? page;
  }

  void _selectDesktopDestination({
    required String destinationId,
    required int branchIndex,
    required Widget page,
  }) {
    if (_showDesktopPlayerWorkspace) {
      setState(() => _showDesktopPlayerWorkspace = false);
    }
    _desktopNavigationStrategy.selectDestination(
      context: context,
      destinationId: destinationId,
      branchIndex: branchIndex,
      page: _desktopPage(destinationId, page),
    );
  }

  void _scheduleHiddenBranchFallback() {
    if (_branchFallbackScheduled) return;
    _branchFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _branchFallbackScheduled = false;
      if (!mounted) return;
      final currentIndex = widget.navigationShell.currentIndex;
      final currentDestinations = echoMainDestinations(
        showExploreTab: ref.read(
          activeEmbedServiceConfigProvider.select((config) {
            return config.isEnabledAndConfigured;
          }),
        ),
      );
      final stillHidden = !currentDestinations.any(
        (destination) => destination.branchIndex == currentIndex,
      );
      if (stillHidden) {
        _goToBranch(discoverBranchIndex);
      }
    });
  }

  Future<void> _handleBackPressed() async {
    final windowClass = context.echoBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    if (windowClass == EchoWindowClass.expanded) {
      if (_showDesktopPlayerWorkspace) {
        setState(() => _showDesktopPlayerWorkspace = false);
        return;
      }
      final scaffold = scaffoldKey.currentState;
      if (scaffold?.isDrawerOpen ?? false) {
        scaffold?.closeDrawer();
        return;
      }
      final rootNavigator = Navigator.of(context);
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
        return;
      }
      if (_desktopNavigationStrategy.canGoBack) {
        await _desktopNavigationStrategy.maybePop();
      }
      // The desktop root is Music Flow. Window close, rather than the
      // Android move-to-background action, exits or hides the desktop app.
      return;
    }
    final index = widget.navigationShell.currentIndex;
    final branchCount = widget.branchNavigatorKeys.length;
    Logger.infoWithTag(
      _logTag,
      'back pressed, branchIndex=$index, branchCount=$branchCount',
    );

    final scaffold = scaffoldKey.currentState;
    final rootNavigator = Navigator.of(context);
    NavigatorState? branchNavigator;
    if (index >= 0 && index < branchCount) {
      final navigatorKey = widget.branchNavigatorKeys[index];
      branchNavigator = navigatorKey.currentState;
      Logger.infoWithTag(
        _logTag,
        'navigator for branch $index: '
        'key=$navigatorKey, '
        'state=${branchNavigator != null ? "present" : "null"}, '
        'canPop=${branchNavigator?.canPop()}',
      );
    } else {
      Logger.warnWithTag(
        _logTag,
        'index $index out of range [0, $branchCount)',
      );
    }

    final action = resolveEchoBackAction(
      drawerOpen: scaffold?.isDrawerOpen ?? false,
      rootCanPop: rootNavigator.canPop(),
      branchCanPop: branchNavigator?.canPop() ?? false,
      currentBranchIndex: index,
    );

    switch (action) {
      case EchoBackAction.closeDrawer:
        Logger.infoWithTag(_logTag, 'drawer is open, closing drawer');
        scaffold?.closeDrawer();
      case EchoBackAction.popRootNavigator:
        Logger.infoWithTag(_logTag, 'root navigator can pop, popping');
        rootNavigator.pop();
      case EchoBackAction.popBranchNavigator:
        Logger.infoWithTag(_logTag, 'branch $index can pop, popping');
        branchNavigator?.pop();
      case EchoBackAction.switchToDiscover:
        Logger.infoWithTag(
          _logTag,
          'non-home branch root reached (index=$index), switching to home tab',
        );
        _goToBranch(discoverBranchIndex);
      case EchoBackAction.moveAppToBackground:
        Logger.infoWithTag(
          _logTag,
          'home branch root reached (index=0), move app to background',
        );
        await _moveAppToBackground();
    }
  }

  void _openDesktopPlayerWorkspace(DesktopPlayerPanel panel) {
    setState(() {
      _desktopPlayerPanel = panel;
      _showDesktopPlayerWorkspace = true;
    });
  }

  List<EchoDesktopSidebarAction> _desktopSidebarActions({
    required bool showExploreTab,
  }) {
    EchoDesktopSidebarAction action({
      required String id,
      required String section,
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
    }) => EchoDesktopSidebarAction(
      id: id,
      section: section,
      label: label,
      icon: icon,
      selected: _desktopSelectedActionId == id,
      onPressed: onPressed,
    );

    return <EchoDesktopSidebarAction>[
      action(
        id: 'music-flow',
        section: '发现',
        label: '音乐流',
        icon: AppIcons.musicFlow,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'music-flow',
          branchIndex: discoverBranchIndex,
          page: DiscoverPage(),
        ),
      ),
      if (showExploreTab)
        action(
          id: 'explore',
          section: '发现',
          label: '探索',
          icon: AppIcons.discover,
          onPressed: () => _selectDesktopDestination(
            destinationId: 'explore',
            branchIndex: exploreBranchIndex,
            page: ExplorePage(),
          ),
        ),
      action(
        id: 'search',
        section: '发现',
        label: '搜索',
        icon: AppIcons.search,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'search',
          branchIndex: discoverBranchIndex,
          page: const SearchPage(),
        ),
      ),
      action(
        id: 'songs',
        section: '资料库',
        label: '全部歌曲',
        icon: AppIcons.music,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'songs',
          branchIndex: catalogBranchIndex,
          page: const SongListPage(),
        ),
      ),
      action(
        id: 'artists',
        section: '资料库',
        label: '歌手',
        icon: AppIcons.profile,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'artists',
          branchIndex: catalogBranchIndex,
          page: const ArtistListPage(),
        ),
      ),
      action(
        id: 'albums',
        section: '资料库',
        label: '专辑',
        icon: AppIcons.albumOutline,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'albums',
          branchIndex: catalogBranchIndex,
          page: const AlbumListPage(),
        ),
      ),
      action(
        id: 'favorite-songs',
        section: '个人收藏',
        label: '收藏歌曲',
        icon: AppIcons.heartOutline,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'favorite-songs',
          branchIndex: libraryBranchIndex,
          page: const StarredPage(initialTab: StarredTab.songs),
        ),
      ),
      action(
        id: 'favorite-albums',
        section: '个人收藏',
        label: '收藏专辑',
        icon: AppIcons.albumOutline,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'favorite-albums',
          branchIndex: libraryBranchIndex,
          page: const StarredPage(initialTab: StarredTab.albums),
        ),
      ),
      action(
        id: 'favorite-artists',
        section: '个人收藏',
        label: '收藏歌手',
        icon: AppIcons.profile,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'favorite-artists',
          branchIndex: libraryBranchIndex,
          page: const StarredPage(initialTab: StarredTab.artists),
        ),
      ),
      action(
        id: 'my-playlists',
        section: '个人收藏',
        label: '我的歌单',
        icon: AppIcons.queue,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'my-playlists',
          branchIndex: libraryBranchIndex,
          page: const LibraryPage(showStarredSection: false, pageTitle: '我的歌单'),
        ),
      ),
      action(
        id: 'downloads',
        section: '管理',
        label: '下载管理',
        icon: AppIcons.downloadOutline,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'downloads',
          branchIndex: libraryBranchIndex,
          page: const DownloadManagerPage(),
        ),
      ),
      action(
        id: 'offline',
        section: '管理',
        label: '离线下载',
        icon: AppIcons.offline,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'offline',
          branchIndex: libraryBranchIndex,
          page: const OfflineDownloadStatusPage(),
        ),
      ),
      action(
        id: 'settings',
        section: '管理',
        label: '设置',
        icon: AppIcons.settings,
        onPressed: () => _selectDesktopDestination(
          destinationId: 'settings',
          branchIndex: libraryBranchIndex,
          page: const AppSettingsPage(),
        ),
      ),
    ];
  }

  Future<void> _showDesktopAppMenu() async {
    final motion = context.echoMotion;
    final duration = motion.resolve(context, motion.state);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final height =
            (MediaQuery.sizeOf(dialogContext).height.clamp(320.0, 760.0) - 64)
                .toDouble();
        return Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 400,
            height: height,
            child: AppDrawer(onReturnFocus: _restoreEchoAppDrawerFocus),
          ),
        );
      },
      barrierColor: context.echoColors.scrim,
      useSafeArea: true,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      routeSettings: const RouteSettings(name: 'desktop-app-menu'),
      animationStyle: duration == Duration.zero
          ? AnimationStyle.noAnimation
          : AnimationStyle(duration: duration, reverseDuration: duration),
    );
    _restoreEchoAppDrawerFocus();
  }

  Future<void> _moveAppToBackground() async {
    try {
      await _appLifecycleChannel.invokeMethod<void>('moveTaskToBack');
      Logger.infoWithTag(_logTag, 'moveTaskToBack invoked');
    } on MissingPluginException {
      // Ignore on non-Android platforms where this channel is not implemented.
      Logger.warnWithTag(_logTag, 'moveTaskToBack channel missing');
    } on PlatformException {
      // Keep app state unchanged if moving to background fails.
      Logger.warnWithTag(_logTag, 'moveTaskToBack invoke failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleVisibleBranchSync();
    final bool hasMiniPlayer = widget.showMiniPlayerOverride != null
        ? widget.showMiniPlayerOverride!
        : ref.watch(
            playerProvider.select((state) => state.currentSong != null),
          );
    final bool showExploreTab = widget.showExploreTabOverride != null
        ? widget.showExploreTabOverride!
        : ref.watch(
            activeEmbedServiceConfigProvider.select((config) {
              return config.isEnabledAndConfigured;
            }),
          );
    final activeAddressIsHealthy = ref.watch(
      activeAddressProvider.select((address) {
        return address?.status == ServerAddressStatus.ok;
      }),
    );
    final activeLibrary = ref.watch(
      authStateProvider.select((state) => state.currentLibrary),
    );
    final activeAddress = ref.watch(activeAddressProvider);
    final networkStatus =
        widget.networkStatusOverride ??
        _resolveNetworkStatus(activeAddressIsHealthy: activeAddressIsHealthy);
    final currentBranchIndex = widget.navigationShell.currentIndex;
    final windowClass = context.echoBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final isDesktop = windowClass == EchoWindowClass.expanded;
    final destinations = echoMainDestinations(showExploreTab: showExploreTab);
    final desktopWorkspaceVisible = isDesktop && _showDesktopPlayerWorkspace;
    final currentBranchIsVisible = destinations.any(
      (destination) => destination.branchIndex == currentBranchIndex,
    );

    if (!isDesktop && !currentBranchIsVisible) {
      _scheduleHiddenBranchFallback();
    }

    final shell = EchoAppShell(
      scaffoldKey: scaffoldKey,
      drawer:
          widget.drawerOverride ??
          AppDrawer(onReturnFocus: _restoreEchoAppDrawerFocus),
      body: isDesktop
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                TickerMode(
                  enabled: false,
                  child: Offstage(
                    offstage: true,
                    child: widget.navigationShell,
                  ),
                ),
                if (_desktopNavigatorMounted)
                  TickerMode(
                    enabled: !desktopWorkspaceVisible,
                    child: Offstage(
                      offstage: desktopWorkspaceVisible,
                      child: _desktopNavigationStrategy.buildNavigator(
                        context,
                        rootPage: widget.desktopRootOverride ?? DiscoverPage(),
                      ),
                    ),
                  ),
                if (desktopWorkspaceVisible)
                  DesktopPlayerWorkspace(
                    panel: _desktopPlayerPanel,
                    onPanelChanged: (panel) => setState(() {
                      _desktopPlayerPanel = panel;
                    }),
                    onClose: () =>
                        setState(() => _showDesktopPlayerWorkspace = false),
                  ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.navigationShell,
                if (_desktopNavigatorMounted)
                  TickerMode(
                    enabled: false,
                    child: Offstage(
                      offstage: true,
                      child: _desktopNavigationStrategy.buildNavigator(
                        context,
                        rootPage: widget.desktopRootOverride ?? DiscoverPage(),
                      ),
                    ),
                  ),
              ],
            ),
      destinations: destinations,
      selectedBranchIndex: currentBranchIsVisible
          ? currentBranchIndex
          : discoverBranchIndex,
      onDestinationSelected: (branchIndex) {
        if (isDesktop && _showDesktopPlayerWorkspace) {
          setState(() => _showDesktopPlayerWorkspace = false);
        }
        _goToBranch(
          branchIndex,
          initialLocation: branchIndex == currentBranchIndex,
        );
      },
      miniPlayer:
          widget.miniPlayerOverride ??
          (isDesktop
              ? DesktopPlaybackBar(onOpenWorkspace: _openDesktopPlayerWorkspace)
              : const MiniPlayer()),
      showMiniPlayer: hasMiniPlayer,
      networkStatus: networkStatus,
      onOpenDrawer: isDesktop ? _showDesktopAppMenu : openEchoAppDrawer,
      desktopActions: isDesktop
          ? _desktopSidebarActions(showExploreTab: showExploreTab)
          : const [],
      desktopNavigationToolbar: isDesktop
          ? EchoDesktopNavigationToolbar(
              canGoBack: _desktopCanGoBack,
              canGoForward: _desktopCanGoForward,
              onBack: () => unawaited(_handleBackPressed()),
              onForward: _navigateDesktopForward,
              onSearch: () => _selectDesktopDestination(
                destinationId: 'search',
                branchIndex: discoverBranchIndex,
                page: const SearchPage(),
              ),
            )
          : null,
      desktopAccountLabel:
          activeLibrary?.username ?? activeLibrary?.name ?? '账户',
      desktopAccountSubtitle: <String>[
        if (activeLibrary?.name.trim().isNotEmpty == true)
          activeLibrary!.name.trim(),
        if (activeAddress?.label.trim().isNotEmpty == true)
          activeAddress!.label.trim(),
      ].join(' · '),
    );

    return BackButtonListener(
      onBackButtonPressed: () async {
        await _handleBackPressed();
        return true;
      },
      child: isDesktop ? _withDesktopShortcuts(shell) : shell,
    );
  }
}
