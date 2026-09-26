import 'dart:async';

import 'package:echoes/core/services/desktop_lifecycle_service.dart';
import 'package:echoes/providers/player/playback_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tray activation asks the desktop window to show and focus', () async {
    const channel = MethodChannel('window_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isMinimized') return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    DesktopLifecycleService.instance.onTrayIconMouseDown();
    await pumpEventQueue();

    expect(calls, <String>['isMinimized', 'show', 'focus']);
  });

  test('tray secondary activation opens the native context menu', () async {
    const channel = MethodChannel('tray_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    DesktopLifecycleService.instance.onTrayIconRightMouseDown();
    await pumpEventQueue();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'popUpContextMenu');
    expect(calls.single.arguments, <String, dynamic>{'bringAppToFront': true});
  });

  group('statusNotifierReconnectDelay', () {
    test('backs off to a capped 30 second retry interval', () {
      expect(statusNotifierReconnectDelay(0), const Duration(seconds: 1));
      expect(statusNotifierReconnectDelay(1), const Duration(seconds: 1));
      expect(statusNotifierReconnectDelay(2), const Duration(seconds: 2));
      expect(statusNotifierReconnectDelay(3), const Duration(seconds: 4));
      expect(statusNotifierReconnectDelay(4), const Duration(seconds: 8));
      expect(statusNotifierReconnectDelay(5), const Duration(seconds: 16));
      expect(statusNotifierReconnectDelay(6), const Duration(seconds: 30));
      expect(statusNotifierReconnectDelay(50), const Duration(seconds: 30));
    });
  });

  group('showWindowWithBestEffortFocus', () {
    test('keeps visible state when the compositor denies focus', () async {
      var visible = false;
      final focusErrors = <Object>[];
      final showErrors = <Object>[];

      final shown = await showWindowWithBestEffortFocus(
        show: () async {},
        focus: () async => throw StateError('focus not granted'),
        onShown: () => visible = true,
        onShowFailure: showErrors.add,
        onFocusFailure: focusErrors.add,
      );

      expect(shown, isTrue);
      expect(visible, isTrue);
      expect(showErrors, isEmpty);
      expect(focusErrors, hasLength(1));
    });

    test('does not mark the window visible when show fails', () async {
      var visible = false;
      var focusRequested = false;
      final showErrors = <Object>[];

      final shown = await showWindowWithBestEffortFocus(
        show: () async => throw StateError('show failed'),
        focus: () async {
          focusRequested = true;
        },
        onShown: () => visible = true,
        onShowFailure: showErrors.add,
        onFocusFailure: (_) {},
      );

      expect(shown, isFalse);
      expect(visible, isFalse);
      expect(focusRequested, isFalse);
      expect(showErrors, hasLength(1));
    });
  });

  group('showWindowWithMinimizeFallback', () {
    test('minimizes when the window cannot be shown', () async {
      final actions = <String>[];
      final showErrors = <Object>[];
      final minimizeErrors = <Object>[];
      var visible = false;

      final shown = await showWindowWithMinimizeFallback(
        show: () async {
          actions.add('show');
          throw StateError('show unavailable');
        },
        focus: () async {
          actions.add('focus');
        },
        minimize: () async {
          actions.add('minimize');
        },
        onShown: () => visible = true,
        onShowFailure: showErrors.add,
        onFocusFailure: (_) {},
        onMinimizeFailure: minimizeErrors.add,
      );

      expect(shown, isFalse);
      expect(visible, isFalse);
      expect(actions, <String>['show', 'minimize']);
      expect(showErrors, hasLength(1));
      expect(minimizeErrors, isEmpty);
    });

    test('keeps a shown window visible when focus is denied', () async {
      final actions = <String>[];
      var visible = false;

      final shown = await showWindowWithMinimizeFallback(
        show: () async {
          actions.add('show');
        },
        focus: () async => throw StateError('focus denied'),
        minimize: () async {
          actions.add('minimize');
        },
        onShown: () => visible = true,
        onShowFailure: (_) {},
        onFocusFailure: (_) => actions.add('focus-denied'),
        onMinimizeFailure: (_) {},
      );

      expect(shown, isTrue);
      expect(visible, isTrue);
      expect(actions, <String>['show', 'focus-denied']);
    });

    test('reports a failed minimize without throwing', () async {
      final minimizeErrors = <Object>[];

      final shown = await showWindowWithMinimizeFallback(
        show: () async => throw StateError('show unavailable'),
        focus: () async {},
        minimize: () async => throw StateError('minimize unavailable'),
        onShown: () {},
        onShowFailure: (_) {},
        onFocusFailure: (_) {},
        onMinimizeFailure: minimizeErrors.add,
      );

      expect(shown, isFalse);
      expect(minimizeErrors, hasLength(1));
    });
  });

  group('closeWindowWithTrayRecovery', () {
    test('minimizes when no tray host is available', () async {
      var hidden = true;
      final actions = <String>[];

      final result = await closeWindowWithTrayRecovery(
        trayAvailableAtStart: false,
        trayAvailableNow: () => false,
        hideWindow: () async {
          actions.add('hide');
        },
        showWindow: () async {
          actions.add('show');
        },
        minimizeWindow: () async {
          actions.add('minimize');
        },
        onHiddenChanged: (value) => hidden = value,
      );

      expect(result, DesktopWindowCloseResult.minimized);
      expect(actions, <String>['minimize']);
      expect(hidden, isFalse);
    });

    test(
      'falls back to taskbar minimize if tray disappears during hide',
      () async {
        var trayAvailable = true;
        var hidden = false;
        final actions = <String>[];

        final result = await closeWindowWithTrayRecovery(
          trayAvailableAtStart: true,
          trayAvailableNow: () => trayAvailable,
          hideWindow: () async {
            actions.add('hide');
            trayAvailable = false;
          },
          showWindow: () async {
            actions.add('show');
          },
          minimizeWindow: () async {
            actions.add('minimize');
          },
          onHiddenChanged: (value) => hidden = value,
        );

        expect(result, DesktopWindowCloseResult.minimized);
        expect(actions, <String>['hide', 'show', 'minimize']);
        expect(hidden, isFalse);
      },
    );

    test(
      'keeps the window hidden while the tray host remains available',
      () async {
        var hidden = false;
        final actions = <String>[];

        final result = await closeWindowWithTrayRecovery(
          trayAvailableAtStart: true,
          trayAvailableNow: () => true,
          hideWindow: () async {
            actions.add('hide');
          },
          showWindow: () async {
            actions.add('show');
          },
          minimizeWindow: () async {
            actions.add('minimize');
          },
          onHiddenChanged: (value) => hidden = value,
        );

        expect(result, DesktopWindowCloseResult.hidden);
        expect(actions, <String>['hide']);
        expect(hidden, isTrue);
      },
    );
  });

  test('exit removes the tray before waiting for playback shutdown', () async {
    const trayChannel = MethodChannel('tray_manager');
    const windowChannel = MethodChannel('window_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(trayChannel, (call) async {
      calls.add('tray:${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      calls.add('window:${call.method}');
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(trayChannel, null);
      messenger.setMockMethodCallHandler(windowChannel, null);
    });

    final playbackStopped = Completer<void>();
    await DesktopLifecycleService.instance.initialize(
      onTogglePlayPause: () async {},
      onPrevious: () async {},
      onNext: () async {},
      onQuit: () {
        calls.add('stop playback');
        return playbackStopped.future;
      },
      onBeforeQuit: () async => true,
      onBeforeHide: ({required trayAvailable}) async => true,
      initialPlaybackSnapshot: const PlaybackSnapshot(
        songId: null,
        entryId: null,
        title: '',
        artist: '',
        album: '',
        artworkReference: null,
        position: Duration.zero,
        duration: Duration.zero,
        isPlaying: false,
        playbackRequested: false,
        isStopped: true,
        isLoading: false,
        hasError: false,
        canPlay: false,
        canPause: false,
        canGoNext: false,
        canGoPrevious: false,
        canSeek: false,
        volume: 1,
        isMuted: false,
        loopMode: LoopMode.off,
        shuffleEnabled: false,
      ),
    );
    calls.clear();

    final exit = DesktopLifecycleService.instance.requestExit();
    await pumpEventQueue();

    expect(calls.take(2), <String>['tray:destroy', 'stop playback']);

    playbackStopped.complete();
    await exit;
  });
}
