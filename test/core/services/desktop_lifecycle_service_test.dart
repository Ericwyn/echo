import 'package:echoes/core/services/desktop_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
