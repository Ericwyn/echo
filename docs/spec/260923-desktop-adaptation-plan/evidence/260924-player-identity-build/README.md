# Shared player identity build — 2026-09-24

Source commit: `14f39032`.

## Change

`MiniPlayer` and `FullPlayerPage` now share `PlayerTrackIdentity` for title/subtitle rendering and Hero wrappers. Each surface still supplies its typography, alignment, line limits, subtitle spacing, and scrolling behavior. Neighbor-track previews disable Hero animation, while the active mini-player track and full player retain the existing Hero tags. Widget regression cases were added but not run.

## Linux release

- Fresh CMake output: `build/linux-lldtmp-2047/linux/x64/release/bundle/`.
- Bundle executable: ELF x86-64; SHA-256 `22de0110628f205af24bc5fbbf7dd548d9a3b5596d4f75cc4e4e87120afe9ad0`.
- `libapp.so` SHA-256: `b8d867d5b408b07406462370808c51fdd7f4bf2b1c51ea774b44957370c36777`.
- Debian package: `build/linux-lldtmp-2047/packages/echoes_1.1.0+2046_amd64.deb`.
- Package metadata: package `echoes`, version `1.1.0+2046`, architecture `amd64`; dependencies are `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `.deb` SHA-256: `10690e7f38fbda5c4704ed7f85193c247e732359958d9a18f2e754fb0188ee9f`.

## Android release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2036`.
- ABI: `arm64-v8a` only.
- The local script automatically incremented from the prior APK's version code `2035`.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `8ac4bc90759e44ea4a1b557f33c787e50e2d47c61fff03a81c42ef09ddfc045c`.

Both release builds and package metadata/signature checks passed. No app was installed or launched. Flutter tests and `flutter analyze` were not run; manual desktop and Android checks remain with the user.
