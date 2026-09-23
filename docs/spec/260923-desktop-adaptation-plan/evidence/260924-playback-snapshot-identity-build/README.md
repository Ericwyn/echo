# Playback snapshot identity build — 2026-09-24

Source commit: `ba35b87d`.

## Shared contract change

`PlaybackSnapshot` now carries the owning `libraryId`, monotonic `sourceGeneration`, and `bufferedPosition` alongside song/queue-entry identity, position, duration, and transport state. The playback session persists its library identity and falls back to the active library when restoring older sessions.

Linux MPRIS derives its track object identity from library plus queue entry and rejects artwork responses from an old library or source generation. Windows SMTC also clears/reloads artwork when those identities change. Android continues to consume the shared contract without creating another player.

Regression cases were added for snapshot projection and same-entry library changes with late artwork. They were not run, per the user's instruction.

## Linux release

- Flutter 3.41.7; Ubuntu 22.04 x86_64; system Clang with Ubuntu LLD 14 extracted under `/tmp`.
- Fresh build directory: `build/linux-lldtmp-2050/linux/x64/release/bundle/`.
- Bundle executable: x86-64 ELF; SHA-256 `f071f13a646d5a14db7d2d57a2095074a72e466f7624393c26b86560b2b03df8`.
- `libapp.so` SHA-256: `939853e3ec7cf764c3afe1a6ab883a98401dc7b1f0d98ba76adbd6d90665543d`.
- Debian package: `build/linux-lldtmp-2050/packages/echoes_1.1.0+2049_amd64.deb`.
- Package metadata: `echoes`, version `1.1.0+2049`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `.deb` SHA-256: `529b551d4baab310972d75d3ed9e169816782cf9b71343d913de75b62e8e8d94`.

## Android release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2039`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `62253a151de3dabefe0ff44105daa0952f03ed466f306b6749a864da9f2c82d3`.

Both release builds and package/signature metadata checks passed. No app was installed or launched. Flutter tests and `flutter analyze` were not run. Linux/Android interaction and Android background playback remain for user verification.
