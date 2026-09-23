# First background-close notice build — 2026-09-24

Application commit: `8f51f1fc`.

## Change

The first close-to-background action now explains how to recover Echoes. If an AppIndicator/SNI host is available, the dialog explains how to reopen the window from the tray; otherwise it explains that Echoes will minimize to the taskbar. The user can cancel and keep the window open. The notice is marked as seen only after the user confirms and the hide/minimize operation succeeds, so canceling or a failed hide does not consume it.

The close-notice preference is stored alongside the desktop close behavior. A SharedPreferences regression test covers the one-time state; it was added but not run.

## Linux release

- Fresh CMake output: `build/linux-lldtmp-2048/linux/x64/release/bundle/`.
- Bundle executable: ELF x86-64; SHA-256 `4cbdca0b4228b57d4ea6a2874522e2c2d444cf761ffb5ba561fcba577a83b975`.
- `libapp.so` SHA-256: `12c7c3e38ba6369d7e1e35e93eb8b3e7496356840b8121e1230269c9c12a5359`.
- Debian package: `build/linux-lldtmp-2048/packages/echoes_1.1.0+2047_amd64.deb`.
- Package metadata: package `echoes`, version `1.1.0+2047`, architecture `amd64`; dependencies are `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `.deb` SHA-256: `229c7636ca67675096af094645b13a76fc8f81aabff41e16fc4f917efa69ea71`.

## Android release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2037`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `47a92946dde2d56cbbbbd5bc61c8d7024942cf8d49a9e9fc265b8780acf284c8`.

Both release builds and package metadata/signature checks passed. No app was installed or launched. Flutter tests and `flutter analyze` were not run; manual close/restore, GNOME and Android checks remain with the user.
