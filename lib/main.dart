import 'dart:async';
import 'dart:ui';

import 'package:echoes/core/utils/logger.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'app.dart';
import 'core/services/background_playback_advisor.dart';

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

      runApp(const ProviderScope(child: App()));
    },
    (error, stackTrace) {
      Logger.errorWithTag('APP', 'Uncaught zone error', error, stackTrace);
    },
  );
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
