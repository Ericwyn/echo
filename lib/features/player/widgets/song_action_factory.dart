import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/echo_design.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/network_error_notifier.dart';
import '../../../core/utils/toast_notifier.dart';
import '../../../data/models/embed_service_config.dart';
import '../../../data/models/song.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/offline_download_provider.dart';
import '../../../providers/player_provider.dart';
import '../../library/pages/album_detail_page.dart';
import '../../library/pages/artist_detail_page.dart';
import '../../library/pages/song_metadata_edit_page.dart';
import 'song_action.dart';

/// Builds the shared business actions for any song-action presenter.
///
/// The presenter owns dismissal and the playlist picker; returned actions do
/// not know about bottom sheets, menus, or other presentation surfaces.
class SongActionFactory {
  SongActionFactory._();

  static const _metadataLogTag = 'METADATA_EDIT';

  static List<SongAction> forSong({
    required ProviderContainer container,
    required BuildContext hostContext,
    required Song song,
    required String? currentSongId,
    required String libraryId,
    required EmbedServiceConfig embedConfig,
    required bool offlineOnly,
    required List<SongAction> extraActions,
    required Future<void> Function() openPlaylistPicker,
  }) {
    final isCurrentSong = currentSongId == song.id;
    final canDownload = libraryId.isNotEmpty;
    final canDownloadPreview =
        canDownload && embedConfig.isEnabledAndConfigured;
    final canEditMetadata =
        embedConfig.isEnabledAndConfigured &&
        !song.isPreview &&
        (song.path?.trim().isNotEmpty ?? false);

    if (offlineOnly) {
      if (extraActions.isNotEmpty) {
        return List<SongAction>.unmodifiable(extraActions);
      }
      return <SongAction>[
        SongAction(
          id: 'playback.song-options.unavailable',
          icon: AppIcons.info,
          title: canDownload ? '暂无可用操作' : '当前不可操作',
          isAvailable: false,
          onPressed: () {},
        ),
      ];
    }

    if (song.isPreview) {
      final previewSource = song.previewSource?.trim();
      return <SongAction>[
        if (!isCurrentSong)
          SongAction(
            id: 'playback.song.play-next',
            icon: AppIcons.queueAdd,
            title: '下一曲播放',
            onPressed: () async {
              await container.read(playbackCommandsProvider).playNext(song);
              _showMessage(hostContext, '已添加试听歌曲到下一曲');
            },
          ),
        SongAction(
          id: 'playback.preview.add-offline',
          icon: AppIcons.downloadOutline,
          title: '添加到离线下载队列',
          isAvailable: canDownloadPreview,
          onPressed: () async {
            try {
              await container
                  .read(offlineDownloadServiceProvider)
                  .enqueuePreviewSong(
                    song: song,
                    libraryId: libraryId,
                    config: embedConfig,
                  );
              _showMessage(hostContext, '已添加「${song.title}」到离线下载队列');
            } catch (error) {
              NetworkErrorNotifier.show('添加试听歌曲失败: $error');
            }
          },
        ),
        SongAction(
          id: 'playback.preview.source',
          icon: AppIcons.cloud,
          title: previewSource == null || previewSource.isEmpty
              ? '远程试听'
              : '远程试听 · $previewSource',
          isAvailable: false,
          onPressed: () {},
        ),
      ];
    }

    final artistName = song.artist?.trim().isNotEmpty == true
        ? song.artist!.trim()
        : '未知歌手';
    final albumName = song.album?.trim().isNotEmpty == true
        ? song.album!.trim()
        : '未知专辑';

    return <SongAction>[
      SongAction(
        id: 'playback.song.toggle-favorite',
        icon: song.starred ? AppIcons.heart : AppIcons.heartOutline,
        title: song.starred ? '取消红心' : '红心',
        isSelected: song.starred,
        onPressed: () async {
          final newStarred = await container
              .read(playerProvider.notifier)
              .toggleSongFavorite(song);
          if (newStarred == null) {
            NetworkErrorNotifier.show('操作失败');
            return;
          }
          _showMessage(hostContext, newStarred ? '已添加红心' : '已取消红心');
        },
      ),
      SongAction(
        id: 'library.playlist.add-song',
        icon: AppIcons.playlistAdd,
        title: '添加到歌单',
        onPressed: () async {
          if (hostContext.mounted) await openPlaylistPicker();
        },
      ),
      SongAction(
        id: 'download.song.enqueue',
        icon: AppIcons.downloadOutline,
        title: '下载',
        isAvailable: canDownload,
        onPressed: () async {
          await container
              .read(downloadServiceProvider)
              .enqueue(song, libraryId: libraryId);
          _showMessage(hostContext, '已添加「${song.title}」到下载队列');
        },
      ),
      if (!isCurrentSong)
        SongAction(
          id: 'playback.song.play-next',
          icon: AppIcons.queueAdd,
          title: '下一曲播放',
          onPressed: () async {
            await container.read(playbackCommandsProvider).playNext(song);
            _showMessage(hostContext, '已添加到下一曲');
          },
        ),
      SongAction(
        id: 'library.artist.open',
        icon: AppIcons.profile,
        title: '歌手：$artistName',
        isAvailable: song.artistId?.trim().isNotEmpty == true,
        onPressed: () async {
          await Navigator.of(hostContext).push<void>(
            EchoPageRoute<void>(
              context: hostContext,
              builder: (_) => ArtistDetailPage(
                artistId: song.artistId!,
                branchIndex: container.read(currentVisibleBranchIndexProvider),
              ),
            ),
          );
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: artistName));
          ToastNotifier.show('已复制歌手: $artistName');
        },
      ),
      SongAction(
        id: 'library.album.open',
        icon: AppIcons.albumOutline,
        title: '专辑：$albumName',
        isAvailable: song.albumId?.trim().isNotEmpty == true,
        onPressed: () async {
          await Navigator.of(hostContext).push<void>(
            EchoPageRoute<void>(
              context: hostContext,
              builder: (_) => AlbumDetailPage(
                albumId: song.albumId!,
                branchIndex: container.read(currentVisibleBranchIndexProvider),
              ),
            ),
          );
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: albumName));
          ToastNotifier.show('已复制专辑: $albumName');
        },
      ),
      if (canEditMetadata)
        SongAction(
          id: 'library.song.edit-metadata',
          icon: AppIcons.editNote,
          title: '修改元数据',
          onPressed: () async {
            Logger.infoWithTag(
              _metadataLogTag,
              'enter editor from options songId=${song.id} '
              'title="${song.title.trim()}" '
              'artist="${(song.artist ?? '').trim()}" '
              'album="${(song.album ?? '').trim()}" '
              'path="${(song.path ?? '').trim()}" '
              'albumId="${(song.albumId ?? '').trim()}" '
              'artistId="${(song.artistId ?? '').trim()}"',
            );
            if (!hostContext.mounted) return;
            await Navigator.of(hostContext).push<bool>(
              EchoPageRoute<bool>(
                context: hostContext,
                builder: (_) => SongMetadataEditPage(song: song),
              ),
            );
          },
        ),
    ];
  }

  static void _showMessage(BuildContext hostContext, String message) {
    if (!hostContext.mounted) return;
    showEchoMessage(hostContext, message);
  }
}
