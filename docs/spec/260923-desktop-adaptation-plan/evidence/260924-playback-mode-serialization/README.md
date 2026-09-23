# Serialized playback mode updates

## Change

- Source commit: `24e5319e`.
- Shuffle and repeat setters, toggles, cycling, and playback-session restoration now pass through one asynchronous mutation queue. Each independent setter reads the other mode after earlier queued work completes, preventing concurrent MPRIS `Shuffle` and `LoopStatus` writes from overwriting each other with stale state.
- Added a regression definition that issues repeat and shuffle changes concurrently and expects both to remain enabled. The test was formatted but not run.
- Pubspec/build version: `1.1.0+2058`.

## Linux release build

- Flutter: 3.41.7; fresh build directory: `build/linux-lldtmp-2069`.
- DEB: `build/linux-lldtmp-2069/packages/echoes_1.1.0+2058_amd64.deb`.
- DEB SHA-256: `0475341b788b5aaf52b178e6747bb4d39036ed9bff30080515cbbb1659230efe`.
- Standalone bundle ZIP: `build/linux-lldtmp-2069/packages/echoes_1.1.0+2058_linux-x64-bundle.zip`.
- ZIP SHA-256: `884489b3c06823e6b116be2fe657661d72b9112af62eab9c8d253a898d74d340`.
- DEB metadata: package `echoes`, version `1.1.0+2058`, architecture `amd64`, dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `dpkg` confirms version 2058 is newer than 2057; the executable is ELF64 x86-64; the ZIP passed `unzip -t`.

## Android release build

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, versionCode `2056`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `5d2514fa9f6bf813981ac98475bd6e0228e304d65e048ca0a7b3dab41a2ce719`.
- The machine-local helper is ignored by Git; its persistent version state is now `2056`, so the next default APK build uses `2057`.

## Remaining verification

- No Flutter test/analyze was run. Neither package was installed or launched.
- GNOME should verify rapid or simultaneous changes to Shuffle and LoopStatus, and Android should verify the mobile four-mode cycle, queue order, notification controls, and background playback.
