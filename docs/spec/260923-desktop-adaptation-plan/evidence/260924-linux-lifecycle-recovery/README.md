# Linux lifecycle recovery build

## Scope

Source commit: `0e832ddb` (`fix(desktop): recover lifecycle after shutdown failures`).

- A failed or timed out `windowManager.destroy()` now attempts to restore the close guard, window/tray listeners, window-state persistence, tray host monitoring, tray icon, and a visible main window. If showing fails, it attempts to minimize the window so the taskbar remains a recovery path.
- Linux StatusNotifier session-bus monitor errors and stream closure now invalidate stale callbacks and retry with 1, 2, 4, 8, 16, then 30 second delays. The delay remains capped at 30 seconds and resets after a stable 30-second connection. Explicit exit cancels pending retries.
- Android code was not changed in this commit.

## Build artifact

- Build directory: `build/linux-lldtmp-2064`
- Command: `flutter build linux --release --no-pub`, then `scripts/package_linux_deb.sh`
- Package: `build/linux-lldtmp-2064/packages/echoes_1.1.0+2053_amd64.deb`
- Package metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`
- SHA-256: `f6e7b48e190b0cb3e696dbd57bc0a5ef875fc09f9357a2cc3d4a028e76b58450`
- Standalone bundle: `build/linux-lldtmp-2064/packages/echoes_1.1.0+2053_linux-x64-bundle.zip`
- Bundle ZIP SHA-256: `3d313cc02e489cfed707dd4980b10256511dca7e5529dc879265a8453965dcdb`
- Bundle integrity: all entries passed `unzip -t`.

## Verification and remaining work

- Linux release compilation, DEB packaging, and standalone bundle packaging succeeded; package metadata, hashes, and ZIP integrity were checked.
- Dart formatting and `git diff --check` succeeded.
- The new reconnect-delay Flutter test was added but not run. `flutter test` and `flutter analyze` were not run at the user's request.
- The package was not installed and the application was not launched. Ubuntu manual checks remain for StatusNotifier host restart, hidden-window recovery, normal close/quit, and destroy failure recovery.
- Windows CI and Android builds were not part of this lifecycle change.
