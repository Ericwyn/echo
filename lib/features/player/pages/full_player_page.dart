import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/design/echo_design.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../../../data/models/audio_quality.dart';
import '../../../data/models/embed_service_config.dart';
import '../../../data/models/song.dart';
import '../../../providers/audio_quality_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/offline_download_provider.dart';
import '../../../providers/palette_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/cover_art_image.dart';
import '../widgets/play_queue_sheet.dart';
import '../widgets/current_lyrics_panel.dart';
import '../widgets/player_hero_helpers.dart';
import '../widgets/playback_controls.dart';
import '../widgets/song_action.dart';
import '../widgets/song_options_sheet.dart';

/// Echo's immersive now-playing scene.
class FullPlayerPage extends ConsumerStatefulWidget {
  const FullPlayerPage({super.key});

  @override
  ConsumerState<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends ConsumerState<FullPlayerPage>
    with TickerProviderStateMixin {
  bool _showLyrics = false;
  bool _showBitRate = false;
  bool _isClosingRoute = false;

  late final AnimationController _lyricsController;
  late final Animation<double> _lyricsProgress;
  Animation<double> _routeForegroundOpacity =
      const AlwaysStoppedAnimation<double>(1);
  CurvedAnimation? _routeForegroundCurvedAnimation;

  @override
  void initState() {
    super.initState();
    _lyricsController = AnimationController(
      vsync: this,
      duration: EchoMotion.standard.state,
      value: _showLyrics ? 1 : 0,
    );
    _lyricsProgress = CurvedAnimation(
      parent: _lyricsController,
      curve: EchoMotion.standard.sceneCurve,
      reverseCurve: EchoMotion.standard.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.echoMotion;
    final stateDuration = motion.resolve(context, motion.state);
    _lyricsController.duration = stateDuration;

    _routeForegroundCurvedAnimation?.dispose();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) {
      _routeForegroundCurvedAnimation = null;
      _routeForegroundOpacity = const AlwaysStoppedAnimation<double>(1);
    } else {
      final foregroundOpacity = CurvedAnimation(
        parent: routeAnimation,
        curve: Interval(0.08, 0.82, curve: motion.easeOut),
        // On pop, fade every non-Hero control out during the first 75% of the
        // route flight. The flipped curve makes the exit decisive up front and
        // prevents any foreground control from flashing on the final frame.
        reverseCurve: Interval(0.25, 1, curve: motion.easeOut.flipped),
      );
      _routeForegroundCurvedAnimation = foregroundOpacity;
      _routeForegroundOpacity = foregroundOpacity;
    }

    if (context.echoReduceMotion) {
      _lyricsController.value = _showLyrics ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _routeForegroundCurvedAnimation?.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _closeToMini() async {
    if (_isClosingRoute || !mounted) return;
    _isClosingRoute = true;
    final navigator = Navigator.of(context);

    try {
      final motion = context.echoMotion;
      final settleDuration = motion.resolve(context, motion.feedback);
      if (_showLyrics || _lyricsController.value > 0) {
        setState(() => _showLyrics = false);
        if (settleDuration == Duration.zero) {
          _lyricsController.value = 0;
        } else {
          await _lyricsController.animateBack(
            0,
            duration: settleDuration,
            curve: motion.easeOut,
          );
        }
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
      }

      if (!mounted) return;
      navigator.pop();
    } catch (_) {
      _isClosingRoute = false;
    }
  }

  String _buildSubtitle(Song song) {
    final artist = song.artist?.trim() ?? '';
    final album = song.album?.trim() ?? '';
    if (artist.isNotEmpty && album.isNotEmpty) return '$artist · $album';
    if (artist.isNotEmpty) return artist;
    return album;
  }

  Widget _buildSongCover(Song song, double size) {
    final previewCover = song.previewCoverUrl?.trim();
    if (song.isPreview && previewCover?.isNotEmpty == true) {
      return Image.network(
        previewCover!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: '${song.title} 封面',
        errorBuilder: (context, error, stackTrace) => Semantics(
          image: true,
          label: '暂无封面',
          child: ExcludeSemantics(
            child: ColoredBox(
              color: context.echoColors.raised,
              child: Center(
                child: Icon(
                  AppIcons.music,
                  size: 56,
                  color: context.echoColors.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CoverArtImage(
      coverArtId: song.coverArt,
      size: size,
      requestSize: 720,
      fit: BoxFit.cover,
      semanticLabel: '${song.title} 封面',
    );
  }

  Future<void> _enqueuePreviewSong(Song song, {bool force = false}) async {
    final activeLibrary = ref.read(activeLibraryProvider);
    if (activeLibrary == null) {
      _showMessage('当前没有活跃音乐库', kind: EchoMessageKind.warning);
      return;
    }

    final config = EmbedServiceConfig.fromLibraryExtensions(
      activeLibrary.extensions,
    );
    try {
      await ref
          .read(offlineDownloadServiceProvider)
          .enqueuePreviewSong(
            song: song,
            libraryId: activeLibrary.id,
            config: config,
            force: force,
          );
      _showMessage(force ? '已重新添加到离线下载队列' : '已添加到离线下载队列');
    } catch (error) {
      if (error.toString().contains('已在离线队列中') && !force) {
        await _showForceRedownloadConfirmation(song);
      } else {
        _showMessage('添加失败: $error', kind: EchoMessageKind.error);
      }
    }
  }

  Future<void> _showForceRedownloadConfirmation(Song song) async {
    if (!mounted) return;
    final confirmed = await showEchoBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => EchoBottomSheet(
        title: '歌曲已存在',
        subtitle: '「${song.title}」已在离线队列中。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '是否重新下载？这会替换队列中已有的任务。',
              style: context.echoTypography.body.copyWith(
                color: context.echoColors.muted,
              ),
            ),
            SizedBox(height: context.echoSpacing.lg),
            EchoButton.primary(
              label: '重新下载',
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            SizedBox(height: context.echoSpacing.xs),
            EchoButton.ghost(
              label: '取消',
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await _enqueuePreviewSong(song, force: true);
  }

  void _showMessage(
    String message, {
    EchoMessageKind kind = EchoMessageKind.info,
  }) {
    if (!mounted) return;
    showEchoMessage(context, message, kind: kind);
  }

  void _showSongActions(Song song) {
    final mediaVisuals =
        ref.read(playerSurfaceMediaVisualsProvider) ??
        EchoMediaVisuals.fromThemeColors(context.echoColors);
    if (song.isPreview) {
      unawaited(
        showSongOptionsSheet(
          context: context,
          song: song,
          mode: SongOptionsSheetMode.offlineOnly,
          mediaVisuals: mediaVisuals,
          extraActions: <SongAction>[
            SongAction(
              id: 'playback.preview.add-offline',
              icon: AppIcons.downloadOutline,
              title: '添加到离线下载队列',
              onPressed: () => _enqueuePreviewSong(song),
            ),
          ],
        ),
      );
      return;
    }
    unawaited(
      showSongOptionsSheet(
        context: context,
        song: song,
        mediaVisuals: mediaVisuals,
      ),
    );
  }

  void _toggleLyrics() {
    final next = !_showLyrics;
    setState(() => _showLyrics = next);
    if (context.echoReduceMotion) {
      _lyricsController.value = next ? 1 : 0;
    } else if (next) {
      _lyricsController.forward();
    } else {
      _lyricsController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(
      playerProvider.select((state) => state.currentSong),
    );

    if (currentSong == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: context.echoColors.canvas,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsets.all(context.echoSpacing.xs),
                    child: EchoIconButton(
                      icon: AppIcons.chevronDown,
                      label: '关闭播放器',
                      onPressed: _closeToMini,
                    ),
                  ),
                ),
                const Expanded(
                  child: EchoEmptyState(
                    title: '暂无播放内容',
                    description: '从音乐流、搜索或资料库选择一首歌曲开始播放。',
                    icon: AppIcons.music,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final visuals =
        ref.watch(playerSurfaceMediaVisualsProvider) ??
        EchoMediaVisuals.fromThemeColors(context.echoColors);
    final subtitle = _buildSubtitle(currentSong);
    final foregroundBrightness = visuals.foreground.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: foregroundBrightness,
      statusBarBrightness: foregroundBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: visuals.stageBottom,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: foregroundBrightness,
    );

    return EchoMediaColorScope(
      visuals: visuals,
      role: EchoMediaSurfaceRole.stage,
      child: Builder(
        builder: (context) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: PopScope<void>(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (!didPop) await _closeToMini();
              },
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Hero(
                        tag: playerBackgroundHeroTag,
                        flightShuttleBuilder:
                            playerBackgroundFlightShuttleBuilder,
                        child: EchoPlayerBackdrop(
                          visuals: visuals,
                          mode: EchoPlayerBackdropMode.stage,
                        ),
                      ),
                    ),
                    _buildRouteForeground(
                      child: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final useWideLayout =
                                constraints.maxWidth > constraints.maxHeight ||
                                constraints.maxWidth >=
                                    context.echoBreakpoints.expanded;
                            return useWideLayout
                                ? _buildWidePlayerLayout(
                                    currentSong,
                                    subtitle: subtitle,
                                  )
                                : _buildPortraitPlayerLayout(
                                    currentSong,
                                    subtitle: subtitle,
                                  );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteForeground({required Widget child}) {
    return FadeTransition(
      key: const ValueKey<String>('full_player_foreground_transition'),
      opacity: _routeForegroundOpacity,
      child: child,
    );
  }

  Widget _buildPortraitPlayerLayout(Song song, {required String subtitle}) {
    return Column(
      key: const ValueKey<String>('full_player_portrait_layout'),
      children: <Widget>[
        _PlayerTopBar(
          song: song,
          onClose: _closeToMini,
          onOpenActions: () => _showSongActions(song),
        ),
        Expanded(child: _buildMiddleContent(song, subtitle: subtitle)),
        _buildControlPanel(song),
      ],
    );
  }

  Widget _buildWidePlayerLayout(Song song, {required String subtitle}) {
    final spacing = context.echoSpacing;
    final horizontalPadding = context.echoWindowClass == EchoWindowClass.compact
        ? spacing.md
        : context.echoPageHorizontalPadding;

    return Column(
      key: const ValueKey<String>('full_player_wide_layout'),
      children: <Widget>[
        _PlayerTopBar(
          song: song,
          onClose: _closeToMini,
          onOpenActions: () => _showSongActions(song),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              spacing.xxs,
              horizontalPadding,
              spacing.xs,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.echoBreakpoints.maxContentWidth,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactWidth =
                          constraints.maxWidth < context.echoBreakpoints.medium;
                      final columnGap = compactWidth ? spacing.sm : spacing.lg;
                      final minimumDetailsWidth = compactWidth ? 248.0 : 320.0;
                      final maxArtworkByWidth =
                          (constraints.maxWidth -
                                  columnGap -
                                  minimumDetailsWidth)
                              .clamp(spacing.xxl, 520.0)
                              .toDouble();
                      final maxArtworkByHeight = constraints.maxHeight
                          .clamp(spacing.xxl, 520.0)
                          .toDouble();
                      final artworkPaneWidth =
                          maxArtworkByWidth < maxArtworkByHeight
                          ? maxArtworkByWidth
                          : maxArtworkByHeight;

                      return Row(
                        children: <Widget>[
                          SizedBox(
                            key: const ValueKey<String>(
                              'full_player_artwork_pane',
                            ),
                            width: artworkPaneWidth,
                            child: _buildWideArtworkPane(song),
                          ),
                          SizedBox(width: columnGap),
                          Expanded(
                            child: _buildWideDetailsPane(
                              song,
                              subtitle: subtitle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideArtworkPane(Song song) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.echoSpacing;
        final maxCoverByWidth = (constraints.maxWidth - spacing.xs * 2).clamp(
          0.0,
          520.0,
        );
        final maxCoverByHeight = (constraints.maxHeight - spacing.xs * 2).clamp(
          0.0,
          520.0,
        );
        final coverSize = maxCoverByWidth < maxCoverByHeight
            ? maxCoverByWidth
            : maxCoverByHeight;

        return AnimatedBuilder(
          animation: _lyricsProgress,
          builder: (context, child) {
            final progress = _lyricsProgress.value;
            final currentCoverSize = coverSize * (1 - progress);
            final shouldBuildLyrics = _showLyrics || progress > 0.001;

            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: <Widget>[
                if (currentCoverSize > 0.5)
                  Center(
                    child: _buildCoverHero(
                      song,
                      currentCoverSize,
                      opacity: 1 - progress,
                    ),
                  ),
                if (shouldBuildLyrics)
                  ExcludeSemantics(
                    excluding: progress < 0.5,
                    child: IgnorePointer(
                      ignoring: progress < 0.5,
                      child: Opacity(
                        opacity: progress,
                        child: const CurrentLyricsPanel(),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWideDetailsPane(Song song, {required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.echoSpacing;
        final compactHeight = constraints.maxHeight < 520;
        final titleStyle =
            (compactHeight
                    ? context.echoTypography.title
                    : context.echoTypography.headline)
                .copyWith(color: context.echoColors.ink);
        final subtitleStyle =
            (compactHeight
                    ? context.echoTypography.metadata
                    : context.echoTypography.body)
                .copyWith(color: context.echoColors.muted);

        return SingleChildScrollView(
          key: const ValueKey<String>('full_player_details_pane'),
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildSongIdentity(
                  song: song,
                  subtitle: subtitle,
                  titleStyle: titleStyle,
                  subtitleStyle: subtitleStyle,
                  textAlign: TextAlign.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  titleMaxLines: 2,
                  subtitleMaxLines: compactHeight ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  scrollable: false,
                ),
                SizedBox(height: spacing.xs),
                _buildControlPanel(song, compact: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiddleContent(Song song, {required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.echoSpacing;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final horizontalPadding =
            context.echoWindowClass == EchoWindowClass.compact
            ? spacing.lg
            : spacing.xl;
        final titleReserve =
            (24 * textScale * 1.18 * 2) +
            (subtitle.isEmpty ? 0 : 15 * textScale * 1.45 * 2) +
            spacing.xxl;
        final maxCoverByWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, 400.0);
        final maxCoverByHeight = (constraints.maxHeight - titleReserve).clamp(
          0.0,
          400.0,
        );
        final coverSize = maxCoverByWidth < maxCoverByHeight
            ? maxCoverByWidth
            : maxCoverByHeight;
        final availableTopSpace =
            (constraints.maxHeight - coverSize - titleReserve) / 2;
        final coverTopSpace = availableTopSpace.clamp(spacing.xs, spacing.xl);
        final expandedTitleStyle = context.echoTypography.headline.copyWith(
          color: context.echoColors.ink,
        );
        final compactTitleStyle = context.echoTypography.title.copyWith(
          color: context.echoColors.ink,
        );
        final expandedSubtitleStyle = context.echoTypography.body.copyWith(
          color: context.echoColors.muted,
        );
        final compactSubtitleStyle = context.echoTypography.metadata.copyWith(
          color: context.echoColors.muted,
        );

        return AnimatedBuilder(
          animation: _lyricsProgress,
          builder: (context, child) {
            final progress = _lyricsProgress.value;
            final currentCoverSize = coverSize * (1 - progress);
            final topSpace = coverTopSpace * (1 - progress);
            final coverGap = spacing.lg + (spacing.xs - spacing.lg) * progress;
            final titleStyle = TextStyle.lerp(
              expandedTitleStyle,
              compactTitleStyle,
              progress,
            )!;
            final subtitleStyle = TextStyle.lerp(
              expandedSubtitleStyle,
              compactSubtitleStyle,
              progress,
            )!;
            final shouldBuildLyrics = _showLyrics || progress > 0.001;
            final identity = _buildSongIdentity(
              song: song,
              subtitle: subtitle,
              titleStyle: titleStyle,
              subtitleStyle: subtitleStyle,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: <Widget>[
                  SizedBox(height: topSpace),
                  if (currentCoverSize > 0.5)
                    _buildCoverHero(
                      song,
                      currentCoverSize,
                      opacity: 1 - progress,
                    ),
                  SizedBox(height: coverGap),
                  if (shouldBuildLyrics) ...<Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (constraints.maxHeight * 0.32)
                            .clamp(72.0, 180.0)
                            .toDouble(),
                      ),
                      child: identity,
                    ),
                    SizedBox(height: spacing.xxs),
                    Expanded(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: progress,
                          child: const CurrentLyricsPanel(),
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: identity,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoverHero(Song song, double size, {double opacity = 1}) {
    return Opacity(
      key: const ValueKey<String>('full_player_cover'),
      opacity: opacity,
      child: Hero(
        tag: playerCoverHeroTag,
        createRectTween: playerCoverRectTween,
        child: Builder(
          builder: (context) {
            return RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.echoColors.raised,
                  borderRadius: context.echoRadii.surface,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: context.echoColors.scrim.withValues(alpha: 0.24),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: context.echoRadii.surface,
                  child: SizedBox.square(
                    dimension: size,
                    child: _buildSongCover(song, size),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongIdentity({
    required Song song,
    required String subtitle,
    required TextStyle titleStyle,
    required TextStyle subtitleStyle,
    TextAlign textAlign = TextAlign.center,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    int? titleMaxLines,
    int? subtitleMaxLines,
    TextOverflow? overflow,
    bool scrollable = true,
  }) {
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        Hero(
          tag: playerTitleHeroTag,
          createRectTween: playerLinearRectTween,
          flightShuttleBuilder: playerTextFlightShuttleBuilder,
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              song.title,
              style: titleStyle,
              textAlign: textAlign,
              maxLines: titleMaxLines,
              overflow: overflow,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...<Widget>[
          SizedBox(height: context.echoSpacing.xxs),
          Hero(
            tag: playerSubtitleHeroTag,
            createRectTween: playerLinearRectTween,
            flightShuttleBuilder: playerTextFlightShuttleBuilder,
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                subtitle,
                style: subtitleStyle,
                textAlign: textAlign,
                maxLines: subtitleMaxLines,
                overflow: overflow,
              ),
            ),
          ),
        ],
      ],
    );

    if (!scrollable) return identity;
    return SingleChildScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      child: identity,
    );
  }

  Widget _buildControlPanel(Song song, {bool compact = false}) {
    final spacing = context.echoSpacing;
    final content = Column(
      key: const ValueKey<String>('full_player_control_panel'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const ProgressBar(),
        SizedBox(height: compact ? spacing.xxs : spacing.sm),
        PlaybackControls(
          key: const ValueKey<String>('full_player_transport_controls'),
          compact: compact,
        ),
        SizedBox(height: compact ? spacing.xxs : spacing.xs),
        _PlayerUtilityBar(
          key: const ValueKey<String>('full_player_utility_bar'),
          currentSong: song,
          showLyrics: _showLyrics,
          onToggleLyrics: _toggleLyrics,
          onOpenQueue: () => unawaited(showPlayQueueSheet(context: context)),
        ),
        SizedBox(height: spacing.xxs),
        _buildQualityIndicator(),
      ],
    );

    if (compact) return content;

    final horizontalPadding = context.echoWindowClass == EchoWindowClass.compact
        ? spacing.md
        : spacing.xl;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        spacing.xs,
        horizontalPadding,
        spacing.sm,
      ),
      child: content,
    );
  }

  String _formatSamplingRate(int rate) {
    final khz = rate / 1000;
    return khz == khz.truncateToDouble()
        ? '${khz.toInt()}kHz'
        : '${khz.toStringAsFixed(1)}kHz';
  }

  String _buildAudioSpecText(Song? song) {
    final bitDepth = song?.bitDepth;
    final samplingRate = song?.samplingRate;
    if (bitDepth != null && samplingRate != null && samplingRate > 0) {
      return '${bitDepth}bit/${_formatSamplingRate(samplingRate)}';
    }
    if (bitDepth != null) return '${bitDepth}bit';
    if (samplingRate != null && samplingRate > 0) {
      return _formatSamplingRate(samplingRate);
    }
    return '';
  }

  String _normalizeQualityPartForCompare(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final bitrateMatch = RegExp(
      r'(\d{2,4})\s*(k|kbps|kbit/s|kb/s)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (bitrateMatch != null) return '${bitrateMatch.group(1)}k';
    return trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  void _appendUniqueQualityPart(List<String> parts, String part) {
    final candidate = part.trim();
    if (candidate.isEmpty) return;
    final normalized = _normalizeQualityPartForCompare(candidate);
    if (parts.any(
      (existing) => _normalizeQualityPartForCompare(existing) == normalized,
    )) {
      return;
    }
    parts.add(candidate);
  }

  Widget _buildQualityIndicator() {
    return Consumer(
      builder: (context, ref, child) {
        final playerState = ref.watch(
          playerProvider.select(
            (state) => (
              currentSong: state.currentSong,
              currentBitRateKbps: state.currentBitRateKbps,
              currentQuality: state.currentQuality,
              playbackSource: state.playbackSource,
            ),
          ),
        );
        final song = playerState.currentSong;
        final rawBitRate = playerState.currentBitRateKbps > 0
            ? playerState.currentBitRateKbps
            : ((song?.bitRate ?? 0) >= 10000
                  ? ((song?.bitRate ?? 0) ~/ 1000)
                  : (song?.bitRate ?? 0));
        final bitRateText = rawBitRate > 0 ? '${rawBitRate}Kbps' : '未知码率';
        final audioSpecText = _buildAudioSpecText(song);
        final parts = <String>[];
        IconData icon;

        if (song?.isPreview == true) {
          final qualityLabel = song?.previewQualityLabel?.trim();
          parts.add('试听');
          _appendUniqueQualityPart(
            parts,
            qualityLabel?.isNotEmpty == true ? qualityLabel! : '未知音质',
          );
          icon = AppIcons.headphones;
        } else {
          final quality =
              playerState.currentQuality ?? ref.watch(effectiveQualityProvider);
          final qualityLabel = switch (quality) {
            AudioQualityLevel.original => '原始无损',
            AudioQualityLevel.high => '高品质',
            AudioQualityLevel.standard => '标准',
            AudioQualityLevel.dataSaver => '流量节省',
            null => '未知音质',
          };
          final source = playerState.playbackSource ?? PlaybackSource.stream;
          switch (source) {
            case PlaybackSource.downloaded:
              parts.add('本地已下载');
              icon = AppIcons.offline;
            case PlaybackSource.cached:
              parts.add('本地缓存');
              icon = AppIcons.checkCircleOutline;
            case PlaybackSource.stream:
              final networkType = ref
                  .watch(currentNetworkTypeProvider)
                  .valueOrNull;
              parts.add(switch (networkType) {
                NetworkType.wifi => 'Wi-Fi',
                NetworkType.mobile => '移动数据',
                NetworkType.none => '无网络',
                null => '未知网络',
              });
              icon = networkType == NetworkType.none
                  ? AppIcons.offline
                  : AppIcons.cloud;
          }
          parts.add(qualityLabel);
        }

        if (_showBitRate) _appendUniqueQualityPart(parts, bitRateText);
        if (audioSpecText.isNotEmpty) {
          _appendUniqueQualityPart(parts, audioSpecText);
        }
        final text = parts.join(' · ');

        return EchoPressable(
          key: const ValueKey<String>('full_player_quality_metadata'),
          semanticLabel: '$text，${_showBitRate ? '点击收起码率' : '点击显示码率'}',
          onPressed: () => setState(() => _showBitRate = !_showBitRate),
          minimumSize: Size(
            context.echoInteraction.minimumTouchTarget,
            context.echoInteraction.minimumTouchTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.echoSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 16, color: context.echoColors.ink),
                SizedBox(width: context.echoSpacing.xs),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.echoTypography.metadata.copyWith(
                      color: context.echoColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.song,
    required this.onClose,
    required this.onOpenActions,
  });

  final Song song;
  final VoidCallback onClose;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.echoSpacing.xs),
      child: SizedBox(
        height: 56,
        child: Row(
          children: <Widget>[
            PlaybackIconButton(
              icon: AppIcons.chevronDown,
              label: '收起播放器',
              onPressed: onClose,
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '正在播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.echoTypography.label.copyWith(
                    color: context.echoColors.ink,
                  ),
                ),
              ),
            ),
            PlaybackIconButton(
              icon: AppIcons.more,
              label: '${song.title} 操作',
              onPressed: onOpenActions,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerUtilityBar extends ConsumerWidget {
  const _PlayerUtilityBar({
    super.key,
    required this.currentSong,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onOpenQueue,
  });

  final Song currentSong;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      playerProvider.select(
        (state) => (
          shuffleEnabled: state.shuffleEnabled,
          loopMode: state.loopMode,
          starred: state.currentSong?.starred ?? currentSong.starred,
        ),
      ),
    );
    final mode = state.shuffleEnabled
        ? PlaybackMode.shuffle
        : state.loopMode == LoopMode.one
        ? PlaybackMode.repeatOne
        : state.loopMode == LoopMode.all
        ? PlaybackMode.repeatAll
        : PlaybackMode.sequential;
    final modeIcon = switch (mode) {
      PlaybackMode.sequential => AppIcons.repeat,
      PlaybackMode.shuffle => AppIcons.shuffle,
      PlaybackMode.repeatAll => AppIcons.repeat,
      PlaybackMode.repeatOne => AppIcons.repeatOne,
    };
    final modeLabel = switch (mode) {
      PlaybackMode.sequential => '顺序播放，播完列表停止，点击切换到列表循环',
      PlaybackMode.repeatAll => '列表循环，点击切换到单曲循环',
      PlaybackMode.repeatOne => '单曲循环，点击切换到随机播放',
      PlaybackMode.shuffle => '随机播放，点击切换到顺序播放',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            PlaybackIconButton(
              icon: modeIcon,
              label: modeLabel,
              selected: mode != PlaybackMode.sequential,
              onPressed: () {
                ref.read(playerProvider.notifier).cyclePlaybackMode();
              },
            ),
            PlaybackIconButton(
              icon: showLyrics ? AppIcons.lyricsFilled : AppIcons.lyrics,
              label: showLyrics ? '显示封面' : '显示歌词',
              selected: showLyrics,
              onPressed: onToggleLyrics,
            ),
            PlaybackIconButton(
              icon: AppIcons.queue,
              label: '播放队列',
              onPressed: onOpenQueue,
            ),
            PlaybackIconButton(
              icon: state.starred ? AppIcons.heart : AppIcons.heartOutline,
              label: state.starred ? '取消红心' : '红心',
              selected: state.starred,
              onPressed: () {
                ref.read(playerProvider.notifier).toggleFavorite();
              },
            ),
          ],
        ),
      ),
    );
  }
}
