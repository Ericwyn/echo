import 'package:flutter/material.dart';

import '../../../core/design/echo_design.dart';
import '../../../providers/navigation_provider.dart';
import '../../../widgets/main_scaffold.dart';
import '../../settings/pages/playback_stats_page.dart';
import '../widgets/library_destination_row.dart';
import 'album_list_page.dart';
import 'artist_list_page.dart';
import 'song_list_page.dart';

/// Browse the complete music library independently of personal collections.
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EchoScaffold(
      topBar: EchoTopBar(
        title: '曲库',
        leading: shouldShowPageDrawerTrigger(context)
            ? EchoIconButton(
                icon: AppIcons.menu,
                label: '打开应用菜单',
                onPressed: openEchoAppDrawer,
              )
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.echoSpacing.md,
              context.echoSpacing.sm,
              context.echoSpacing.md,
              context.echoSpacing.xxl + context.echoShellBottomObstruction,
            ),
            children: <Widget>[
              const EchoSectionHeader(title: '统计'),
              LibraryDestinationRow(
                icon: AppIcons.analytics,
                title: '统计信息',
                detail: '音乐库、播放、收藏与缓存统计',
                onPressed: () => _push(
                  context,
                  const PlaybackStatsPage(branchIndex: catalogBranchIndex),
                ),
              ),
              SizedBox(height: context.echoSpacing.xl),
              const EchoSectionHeader(title: '完整曲库'),
              LibraryDestinationRow(
                icon: AppIcons.music,
                title: '全部歌曲',
                detail: '按标题、歌手或专辑排序',
                onPressed: () => _push(context, const SongListPage()),
              ),
              LibraryDestinationRow(
                icon: AppIcons.albumOutline,
                title: '按专辑浏览',
                detail: '查看封面与发行信息',
                onPressed: () => _push(context, const AlbumListPage()),
              ),
              LibraryDestinationRow(
                icon: AppIcons.profile,
                title: '按歌手浏览',
                detail: '从歌手进入专辑与热门曲目',
                onPressed: () => _push(context, const ArtistListPage()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push<void>(EchoPageRoute<void>(context: context, builder: (_) => page));
  }
}
