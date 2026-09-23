# Shared audio-spec formatter build — 2026-09-24

Source commit: `23729951`.

## Change

`AudioSpecFormatter` now provides one shared formatter for playback surfaces on Android and desktop. Non-positive bit depth and sample rate values are treated as missing, so invalid metadata cannot render as `0bit`. A focused unit test covers valid combined output and missing/invalid values; it was added but not run.

The machine-local Android helper at `scripts/local/build_android_release_arm64.sh` remains excluded by `.git/info/exclude`. It reads the local signing material, creates only an `arm64-v8a` APK, increments the base Flutter build number from the previous APK, and validates the final version code and signing certificate. Flutter adds 2000 to the base build number for an arm64 split APK, so base build number 35 produces Android version code 2035. The script is intentionally not committed.

## Linux release

- Fresh CMake output: `build/linux-lldtmp-2046/linux/x64/release/bundle/`.
- Bundle executable: ELF x86-64; SHA-256 `d39c11197d272336e6e6f2327e5497009fa40771056c9a0495a93cbd8f6bee4d`.
- `libapp.so` SHA-256: `1b222c0916849969648acd7559c861155a8e8375ac89311955581668f91bf1d0`.
- Debian package: `build/linux-lldtmp-2046/packages/echoes_1.1.0+2045_amd64.deb`.
- Package metadata: package `echoes`, version `1.1.0+2045`, architecture `amd64`; dependencies are `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `.deb` SHA-256: `c31eb505846cd93cdcf99a7158fe169064bd1e0a7ac9fcdd7777d73424f86e54`.

## Android release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2035`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `00e10ebea82f4704406663a63f4048649fb6fd6bfdc9c9ac7f36f73f405a3843`.

Both release builds completed and package metadata/signing checks passed. No application was installed or launched. No Flutter tests or `flutter analyze` were run; manual Linux and Android interaction checks remain with the user.
