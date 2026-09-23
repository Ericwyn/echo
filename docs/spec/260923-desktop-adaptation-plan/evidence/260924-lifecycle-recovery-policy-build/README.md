# Desktop lifecycle recovery policy build — 2026-09-24

Source commit: `bb8d9af3`.

The close/recovery decisions are now factored into testable helpers. New regression cases cover no tray host, a host disappearing while hide is pending, a stable host, successful show with denied focus, and failed show. These tests were added but not run.

## Linux release

- Flutter 3.41.7; fresh build directory: `build/linux-lldtmp-2060/`.
- Debian package: `build/linux-lldtmp-2060/packages/echoes_1.1.0+2053_amd64.deb` (18,285,290 bytes).
- Metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`; package preflight and `dpkg-deb -I` inspection passed.
- Bundle executable SHA-256: `e18ddefa5e959afc6cbc459b645dc2cf874fc4e9875bac68ed95be347af2499a`.
- `libapp.so` SHA-256: `e7b808071ba20a72ed3933e51c878e7192a77bc5a8666f0e04f3113f9b524848`.
- `.deb` SHA-256: `ae3fd50bf02c758f663cd2fd5f41c3b935eb1d116299a87e31802f0f91bd8281`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (29,741,141 bytes).
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2050`.
- ABI: `arm64-v8a` only; release signature and package metadata verified by the local build helper.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `f6869a539a4e11693441bb9edafce7918a4c5afebc096ce1d9eccc2dd8063f5f`.

Both release builds passed. `dart format` and `git diff --check` passed. No Flutter tests or `flutter analyze` were run. Neither artifact was installed or launched; user manual desktop and Android validation remains required.
