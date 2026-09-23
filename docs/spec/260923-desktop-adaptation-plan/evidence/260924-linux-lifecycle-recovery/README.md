# Linux lifecycle recovery build

## Scope

Source commit: `e34563ef` (watcher retry startup-race fix), including the lifecycle recovery change from `0e832ddb`.

- A failed or timed out `windowManager.destroy()` now attempts to restore the close guard, window/tray listeners, window-state persistence, tray host monitoring, tray icon, and a visible main window. If showing fails, it attempts to minimize the window so the taskbar remains a recovery path.
- Linux StatusNotifier session-bus monitor errors and stream closure now invalidate stale callbacks and retry with 1, 2, 4, 8, 16, then 30 second delays. The delay remains capped at 30 seconds and resets after a stable 30-second connection. Explicit exit cancels pending retries. Commit `e34563ef` preserves a retry if exit recovery races the initial watcher lookup.
- Android code was not changed in this commit.

## Build artifact

- Build directory: `build/linux-lldtmp-2064`
- Command: `flutter build linux --release --no-pub`, then `scripts/package_linux_deb.sh`
- Package: `build/linux-lldtmp-2064/packages/echoes_1.1.0+2053_amd64.deb`
- Package metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`
- SHA-256: `aef145de81ef8dfe9de179150a6555ecde738632c2e67636015047f929c43701`
- Standalone bundle: `build/linux-lldtmp-2064/packages/echoes_1.1.0+2053_linux-x64-bundle.zip`
- Bundle ZIP SHA-256: `6d9ad00606b37d66325c21c90d17c4b49b0f9bc48125b9dc103356fa7fa2e3c4`
- Bundle integrity: all entries passed `unzip -t`.

## Verification and remaining work

- Linux release compilation, DEB packaging, and standalone bundle packaging succeeded; package metadata, hashes, and ZIP integrity were checked.
- Dart formatting and `git diff --check` succeeded.
- The new reconnect-delay Flutter test was added but not run. `flutter test` and `flutter analyze` were not run at the user's request.
- The package was not installed and the application was not launched. Ubuntu manual checks remain for StatusNotifier host restart, hidden-window recovery, normal close/quit, and destroy failure recovery.
- Windows CI and Android builds were not part of this lifecycle change.
