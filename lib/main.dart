import 'dart:async';
import 'dart:ui';

import 'package:echoes/core/utils/logger.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/design/echo_design.dart';
import 'core/design/layout/echo_desktop_metrics.dart';
import 'core/services/background_playback_advisor.dart';
import 'core/services/desktop_lifecycle_service.dart';
import 'core/services/desktop_window_state_service.dart';
import 'data/models/download_task.dart';
import 'providers/download_provider.dart';
import 'providers/player_provider.dart';
import 'widgets/main_scaffold.dart' show scaffoldKey;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Logger.initializePlaybackLogs();
      WidgetsBinding.instance.addObserver(_PlaybackLifecycleObserver());
      final isDesktopMediaKitPlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows);
      if (isDesktopMediaKitPlatform) {
        await windowManager.ensureInitialized();
        await windowManager.setMinimumSize(
          const Size(
            echoDesktopMinimumWindowWidth,
            echoDesktopMinimumWindowHeight,
          ),
        );
        if (defaultTargetPlatform == TargetPlatform.linux) {
          // Echo has no always-on-top mode; clear a stale window-manager hint
          // before showing the app again.
          await windowManager.setAlwaysOnTop(false);
          await windowManager.setResizable(true);
          await windowManager.setMaximizable(true);
          await windowManager.setMinimizable(true);
          // GNOME's GTK header bar currently renders its own title strip. Hide
          // it before Flutter's first frame; Echo draws the Linux window chrome.
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
          await windowManager.setAsFrameless();
        }
        await DesktopWindowStateService.restoreBeforeFirstFrame();
        JustAudioMediaKit.ensureInitialized();
      }

      FlutterError.onError = (details) {
        Logger.errorWithTag(
          'APP',
          'Flutter framework error',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        Logger.errorWithTag('APP', 'Uncaught platform error', error, stack);
        return true;
      };

      runApp(const ProviderScope(child: _DesktopLifecycleHost(child: App())));
    },
    (error, stackTrace) {
      Logger.errorWithTag('APP', 'Uncaught zone error', error, stackTrace);
    },
  );
}

class _DesktopLifecycleHost extends ConsumerStatefulWidget {
  const _DesktopLifecycleHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_DesktopLifecycleHost> createState() =>
      _DesktopLifecycleHostState();
}

class _DesktopLifecycleHostState extends ConsumerState<_DesktopLifecycleHost> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.linux &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDesktopLifecycle();
    });
  }

  Future<void> _initializeDesktopLifecycle() async {
    try {
      await DesktopWindowStateService.instance.initialize();
      await DesktopLifecycleService.instance.initialize(
        initialPlaybackSnapshot: ref.read(playbackSnapshotProvider),
        onTogglePlayPause: () async {
          final player = ref.read(playerProvider.notifier);
          await player.initialized;
          await ref.read(playbackCommandsProvider).togglePlayPause();
        },
        onPrevious: () async {
          final player = ref.read(playerProvider.notifier);
          await player.initialized;
          await ref.read(playbackCommandsProvider).previous();
        },
        onNext: () async {
          final player = ref.read(playerProvider.notifier);
          await player.initialized;
          await ref.read(playbackCommandsProvider).next();
        },
        onQuit: () async {
          final player = ref.read(playerProvider.notifier);
          await player.initialized;
          await player.stopForDesktopExit();
        },
        onBeforeQuit: _confirmDesktopQuit,
        onBeforeHide: _confirmFirstBackgroundClose,
      );
    } catch (error, stackTrace) {
      Logger.warnWithTag('DESKTOP', 'desktop lifecycle setup failed', error);
      Logger.debugWithTag('DESKTOP', 'lifecycle stack', stackTrace);
    }
  }

  Future<bool> _confirmFirstBackgroundClose({
    required bool trayAvailable,
  }) async {
    final dialogContext = ref
        .read(appRootNavigatorKeyProvider)
        .currentState
        ?.overlay
        ?.context;
    if (dialogContext == null) return false;

    final recoveryPath = trayAvailable
        ? '关闭窗口后，Echoes 会继续播放。可点击系统托盘中的 Echoes 图标，再选择“显示 Echo”恢复窗口。'
        : '当前会话没有可用的系统托盘，Echoes 会最小化到任务栏而不是退出。可从任务栏恢复窗口。';
    final hideLabel = trayAvailable ? '隐藏到托盘' : '最小化到任务栏';

    return await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Echoes 将继续在后台运行'),
            content: Text('$recoveryPath\n\n也可以到设置中改为关闭窗口时退出。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('继续使用'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(hideLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmDesktopQuit() async {
    try {
      final tasks = await ref.read(downloadRepositoryProvider).getAllTasks();
      final activeTasks = tasks
          .where(
            (task) =>
                task.status == DownloadTaskStatus.pending ||
                task.status == DownloadTaskStatus.downloading,
          )
          .toList(growable: false);
      if (activeTasks.isEmpty) return true;

      await DesktopLifecycleService.instance.showWindow();
      final dialogContext = scaffoldKey.currentContext;
      if (dialogContext == null) return false;

      final shouldPauseAndQuit = await showDialog<bool>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: const Text('下载任务仍在进行'),
          content: Text(
            '有 ${activeTasks.length} 个本地下载任务未完成。退出会中断下载。'
            '你可以先取消退出，或暂停任务并退出；下次可在下载管理中继续。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消退出'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('暂停下载并退出'),
            ),
          ],
        ),
      );
      if (shouldPauseAndQuit != true) return false;

      await ref.read(downloadServiceProvider).pauseAll();
      return true;
    } catch (error, stackTrace) {
      Logger.warnWithTag('DESKTOP', 'download-aware exit failed', error);
      Logger.debugWithTag('DESKTOP', 'exit stack', stackTrace);
      await DesktopLifecycleService.instance.showWindow();
      final context = scaffoldKey.currentContext;
      if (context != null) {
        showEchoMessage(
          context,
          '读取或暂停下载任务失败，Echoes 仍保持打开。',
          kind: EchoMessageKind.error,
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      ref.listen(playbackSnapshotProvider, (previous, next) {
        unawaited(
          DesktopLifecycleService.instance.updatePlaybackSnapshot(next),
        );
      });
    }
    return widget.child;
  }
}

class _PlaybackLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.infoWithTag('PLAYBACK', 'app lifecycle=${state.name}');
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Wait for the foreground frame so the hint is visible after unlocking.
      if (state == AppLifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          BackgroundPlaybackAdvisor.instance.onLifecycle(
            WidgetsBinding.instance.lifecycleState ?? state,
          );
        });
      } else {
        BackgroundPlaybackAdvisor.instance.onLifecycle(state);
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(Logger.flushPlaybackLogs());
    }
  }
}
