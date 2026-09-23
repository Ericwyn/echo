# Library deletion active-selection fix — 2026-09-24

Source commit: `d85868f1`.

Deleting an inactive library now leaves the current active library and player untouched. Deleting the active library still prepares/stops the outgoing player and selects a remaining library. If the active row has already been deleted but selecting a replacement fails, the app logs out rather than leaving authentication pointed at a deleted library.

## Linux release

- Flutter 3.41.7; fresh CMake build directory: `build/linux-lldtmp-2055/`.
- Debian package: `build/linux-lldtmp-2055/packages/echoes_1.1.0+2053_amd64.deb`.
- Metadata: package `echoes`, version `1.1.0+2053`, architecture `amd64`; bundle preflight and package metadata passed.
- Bundle executable SHA-256: `c356296df593926b6295fbba974bedf42efa8466aa155bd655caa3e3d9e56641`.
- `libapp.so` SHA-256: `c2e9a5d82b390a324a134dec27d3fbaaff467c5625b3c3a02349bfaf8c9ff5c6`.
- `.deb` SHA-256: `5c67d11d850e573e40f8b368e516492952c8c9e2a8f99549ad9e24b95c957c09`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2044`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `e2c0ebebb76b02e7722f87347e0f3ff147f372b5c613184c79b4210c11067c25`.

Both release builds passed. Neither artifact was installed or launched. Flutter tests and `flutter analyze` were not run; active/inactive deletion behavior remains for manual verification.
