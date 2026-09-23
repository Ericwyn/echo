# Library-scoped playback session build — 2026-09-24

Source commit: `6f0f80e6`.

## Changes

- Playback sessions are stored per music-library ID, so switching libraries does not restore another library's queue. Legacy sessions are migrated only when their recorded library matches the active one.
- Library switching saves and stops the outgoing player, clears stale system media metadata, then rebinds AudioService commands to the new notifier.
- AudioService initialization is process-wide on Android and can retry after initialization failure. A notifier disposed while initialization is pending no longer disposes the shared audio engine.
- Added focused regression cases for session isolation, selective clearing, legacy migration, command rebinding, and clearing system media metadata. They were not run per the user's instruction.

## Linux release

- Flutter 3.41.7; fresh CMake build directory: `build/linux-lldtmp-2052/`.
- Built the release bundle with system Clang and Ubuntu LLD 14 extracted under `/tmp`.
- Debian package: `build/linux-lldtmp-2052/packages/echoes_1.1.0+2050_amd64.deb`.
- Metadata: package `echoes`, version `1.1.0+2050`, architecture `amd64`; dependency metadata includes GTK 3, Ayatana AppIndicator, and libmpv.
- Bundle executable SHA-256: `f1a43230ea670e447a008eda866caff751c5c45bf239100d114896429eb14898`.
- `libapp.so` SHA-256: `3893c9dd63eb7539367aa2dd92f848f094d40d64eaa1c23d90b06243d568a569`.
- `.deb` SHA-256: `7be0cd7ff14d5c008636afa7d3090354687a927a704ea7762b82c57a3904027e`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2041` (above the user's installed baseline `2026`).
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `5a0667e7b397453421c89652b8ce42b7663a2002352118e899b5e8edaba429da`.

The machine-local helper `scripts/local/build_android_release_arm64.sh` built and verified the APK. It remains excluded by `.git/info/exclude` and is intentionally not committed because it contains this machine's signing-file locations. It checks that the APK version code advances, contains only ARM64 libraries, and matches the expected release certificate.

Neither package was installed or launched. No Flutter tests or `flutter analyze` were run. Ubuntu interaction and Android install/background playback checks remain for the user.
