# Tray menu snapshot build — 2026-09-24

Source commit: `94b7a2ab`.

## Change

The tray menu now has explicit Previous and Next actions. Play/Pause label and transport availability are derived from the shared `PlaybackSnapshot`. A small `DesktopTrayMenuState` value intentionally ignores position and duration, so ordinary progress updates do not rebuild the native menu.

`tray_manager` invokes both a menu item's `onClick` callback and `TrayListener.onTrayMenuItemClick` for the same event. The menu now leaves per-item callbacks unset and routes all commands through the listener once, preventing duplicate toggles/next actions.

Unit tests cover state-to-menu mapping and verify position-only snapshot changes preserve tray menu state. They were added but not run.

## Linux release

- Fresh CMake output: `build/linux-lldtmp-2049/linux/x64/release/bundle/`.
- Bundle executable: ELF x86-64; SHA-256 `050410aa2fd70f2c4ad04bd613002396d8e0eb5a43d58d2774a8fbc1927fb63a`.
- `libapp.so` SHA-256: `6929c076ad8f408191db7143bc2cd4743df63379340bf7fe552e7f9ef0081cb7`.
- Debian package: `build/linux-lldtmp-2049/packages/echoes_1.1.0+2048_amd64.deb`.
- Package metadata: package `echoes`, version `1.1.0+2048`, architecture `amd64`; dependencies are `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `.deb` SHA-256: `5e216ef9c8eea67eeb3de9de8d985d321d16bb29c74c5cde5c692a1199b2b048`.

## Android release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2038`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `ff379993790e2f227f99b000168a7e78b6278ffb0153a924fc549f85fac85bc7`.
- The ignored local build helper now remembers the last verified version code under `$XDG_STATE_HOME/echoes/` (or `~/.local/state/echoes/`) so removing the build output cannot reset the next build below the installed version.

Both release builds and package metadata/signature checks passed. No app was installed or launched. Flutter tests and `flutter analyze` were not run; tray command uniqueness and Android background behavior remain for user verification.
