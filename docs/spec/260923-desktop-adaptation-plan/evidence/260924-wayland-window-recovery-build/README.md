# Wayland window recovery build — 2026-09-24

Source commit: `8acd46dd` (includes tray-hide recovery from `d6bb46f5`).

Window visibility now updates as soon as `windowManager.show()` succeeds. A denied focus request is logged separately and does not leave the lifecycle service believing the visible window is hidden. The close recovery path also clears its hidden marker when a fallback `show()` succeeds.

## Linux release

- Flutter 3.41.7; fresh build directory: `build/linux-lldtmp-2059/`.
- Debian package: `build/linux-lldtmp-2059/packages/echoes_1.1.0+2053_amd64.deb` (18,285,910 bytes).
- Metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`; package preflight and `dpkg-deb -I` inspection passed.
- Bundle executable SHA-256: `16b476bf4a4dcad68eb90df6734bf9c77bd3210a075513cd809640ee6459208c`.
- `libapp.so` SHA-256: `b583270c10b7573618006e47612dda7bde7ca7dc174b93089d0b1b671e677207`.
- `.deb` SHA-256: `6536ce3349d1669c8db43c3e6e02aed1ee6f36773b570c198521eb94d4fbe3a9`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (29,741,141 bytes).
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2049`.
- ABI: `arm64-v8a` only; release signature and package metadata verified by the local build helper.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `a2311a4fd2361b33efd65c52315bd5a211022ac22e5206168ae07ebc72d41b93`.

Neither artifact was installed or launched. No Flutter tests or `flutter analyze` were run. Ubuntu window-show, focus denial, tray loss, and taskbar recovery require manual desktop validation; Android behavior remains for device regression.
