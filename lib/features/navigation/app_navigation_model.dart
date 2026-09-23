import 'package:flutter/material.dart';

import '../discover/pages/discover_page.dart';
import '../discover/pages/search_page.dart';
import '../download/pages/download_manager_page.dart';
import '../explore/pages/explore_page.dart';
import '../library/pages/album_list_page.dart';
import '../library/pages/artist_list_page.dart';
import '../library/pages/catalog_page.dart';
import '../library/pages/library_page.dart';
import '../library/pages/song_list_page.dart';
import '../library/pages/starred_page.dart';
import '../offline/pages/offline_download_status_page.dart';
import '../settings/pages/app_settings_page.dart';
import '../../providers/navigation_provider.dart';
import '../../core/theme/app_icons.dart';

/// A destination or drawer action consumed by the responsive navigation shells.
///
/// Stable IDs and page targets live here so desktop and compact presenters do
/// not independently define the same library-management destinations.
@immutable
class AppNavigationItem {
  const AppNavigationItem({
    required this.id,
    required this.icon,
    this.selectedIcon,
    this.primaryLabel,
    this.desktopSection,
    this.desktopLabel,
    this.drawerLabel,
    this.drawerSection,
    this.branchIndex,
    this.pageBuilder,
  });

  final String id;
  final IconData icon;
  final IconData? selectedIcon;
  final String? primaryLabel;
  final String? desktopSection;
  final String? desktopLabel;
  final String? drawerLabel;
  final String? drawerSection;
  final int? branchIndex;
  final Widget Function()? pageBuilder;

  String get drawerTitle => drawerLabel ?? desktopLabel ?? '';

  bool get isDesktopDestination =>
      desktopSection != null &&
      desktopLabel != null &&
      branchIndex != null &&
      pageBuilder != null;

  bool get isPrimaryDestination =>
      primaryLabel != null && branchIndex != null && selectedIcon != null;
}

/// Shared route definitions for the desktop sidebar and compact drawer.
class AppNavigationModel {
  AppNavigationModel._();

  static final AppNavigationItem _musicFlow = AppNavigationItem(
    id: 'music-flow',
    desktopSection: '发现',
    desktopLabel: '音乐流',
    primaryLabel: '音乐流',
    icon: AppIcons.musicFlow,
    selectedIcon: AppIcons.musicFlowFilled,
    branchIndex: discoverBranchIndex,
    pageBuilder: () => DiscoverPage(),
  );

  static final AppNavigationItem _explore = AppNavigationItem(
    id: 'explore',
    desktopSection: '发现',
    desktopLabel: '探索',
    primaryLabel: '探索',
    icon: AppIcons.discover,
    selectedIcon: AppIcons.discoverFilled,
    branchIndex: exploreBranchIndex,
    pageBuilder: () => ExplorePage(),
  );

  static final AppNavigationItem _library = AppNavigationItem(
    id: 'library',
    primaryLabel: '我的',
    icon: AppIcons.personal,
    selectedIcon: AppIcons.personalFilled,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const LibraryPage(),
  );

  static final AppNavigationItem _catalog = AppNavigationItem(
    id: 'catalog',
    primaryLabel: '曲库',
    icon: AppIcons.catalog,
    selectedIcon: AppIcons.catalogFilled,
    branchIndex: catalogBranchIndex,
    pageBuilder: () => const CatalogPage(),
  );

  static final AppNavigationItem _search = AppNavigationItem(
    id: 'search',
    desktopSection: '发现',
    desktopLabel: '搜索',
    icon: AppIcons.search,
    branchIndex: discoverBranchIndex,
    pageBuilder: () => const SearchPage(),
  );

  static final AppNavigationItem _songs = AppNavigationItem(
    id: 'songs',
    desktopSection: '资料库',
    desktopLabel: '全部歌曲',
    icon: AppIcons.music,
    branchIndex: catalogBranchIndex,
    pageBuilder: () => const SongListPage(),
  );

  static final AppNavigationItem _artists = AppNavigationItem(
    id: 'artists',
    desktopSection: '资料库',
    desktopLabel: '歌手',
    icon: AppIcons.profile,
    branchIndex: catalogBranchIndex,
    pageBuilder: () => const ArtistListPage(),
  );

  static final AppNavigationItem _albums = AppNavigationItem(
    id: 'albums',
    desktopSection: '资料库',
    desktopLabel: '专辑',
    icon: AppIcons.albumOutline,
    branchIndex: catalogBranchIndex,
    pageBuilder: () => const AlbumListPage(),
  );

  static final AppNavigationItem _favoriteSongs = AppNavigationItem(
    id: 'favorite-songs',
    desktopSection: '个人收藏',
    desktopLabel: '收藏歌曲',
    icon: AppIcons.heartOutline,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const StarredPage(initialTab: StarredTab.songs),
  );

  static final AppNavigationItem _favoriteAlbums = AppNavigationItem(
    id: 'favorite-albums',
    desktopSection: '个人收藏',
    desktopLabel: '收藏专辑',
    icon: AppIcons.albumOutline,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const StarredPage(initialTab: StarredTab.albums),
  );

  static final AppNavigationItem _favoriteArtists = AppNavigationItem(
    id: 'favorite-artists',
    desktopSection: '个人收藏',
    desktopLabel: '收藏歌手',
    icon: AppIcons.profile,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const StarredPage(initialTab: StarredTab.artists),
  );

  static final AppNavigationItem _myPlaylists = AppNavigationItem(
    id: 'my-playlists',
    desktopSection: '个人收藏',
    desktopLabel: '我的歌单',
    icon: AppIcons.queue,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const LibraryPage(
      showStarredSection: false,
      pageTitle: '我的歌单',
      showPlaylistSectionHeader: false,
    ),
  );

  static final AppNavigationItem _routeSelection = AppNavigationItem(
    id: 'route-selection',
    drawerSection: '线路',
    drawerLabel: '切换线路',
    icon: AppIcons.router,
  );

  static final AppNavigationItem _downloads = AppNavigationItem(
    id: 'downloads',
    desktopSection: '管理',
    desktopLabel: '下载管理',
    drawerLabel: '下载管理',
    drawerSection: '下载',
    icon: AppIcons.downloadOutline,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const DownloadManagerPage(),
  );

  // Compact layouts keep access to remote conversion jobs in the overflow
  // drawer. The desktop sidebar omits this low-frequency status page.
  static final AppNavigationItem _offlineDownloads = AppNavigationItem(
    id: 'offline',
    drawerLabel: '离线下载状态',
    drawerSection: '下载',
    icon: AppIcons.offline,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const OfflineDownloadStatusPage(),
  );

  static final AppNavigationItem _settings = AppNavigationItem(
    id: 'settings',
    desktopSection: '管理',
    desktopLabel: '设置',
    drawerLabel: '设置',
    drawerSection: '设置',
    icon: AppIcons.settings,
    branchIndex: libraryBranchIndex,
    pageBuilder: () => const AppSettingsPage(),
  );

  static final List<AppNavigationItem> _desktopItems = <AppNavigationItem>[
    _musicFlow,
    _explore,
    _search,
    _songs,
    _artists,
    _albums,
    _favoriteSongs,
    _favoriteAlbums,
    _favoriteArtists,
    _myPlaylists,
    _downloads,
    _settings,
  ];

  static List<AppNavigationItem> primaryDestinations({
    required bool showExploreTab,
  }) => List<AppNavigationItem>.unmodifiable(<AppNavigationItem>[
    _musicFlow,
    if (showExploreTab) _explore,
    _library,
    _catalog,
  ]);

  static List<AppNavigationItem> desktopSidebar({
    required bool showExploreTab,
  }) => List<AppNavigationItem>.unmodifiable(
    _desktopItems.where((item) => showExploreTab || item.id != 'explore'),
  );

  static List<AppNavigationItem> get drawerActions =>
      List<AppNavigationItem>.unmodifiable(<AppNavigationItem>[
        _routeSelection,
        _downloads,
        _offlineDownloads,
        _settings,
      ]);
}
