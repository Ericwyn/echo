# Shared player layer build evidence

Date: 2026-09-24

Source commit: `7eea69e9`

Scope: compile the shared playback controls, song action contract, and `PlaybackCommands` UI integration on Linux and Android. Builds only; no app launch, installation, Flutter tests, or `flutter analyze` were performed.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2040`.
- Release bundle compiled, then packaged with `scripts/package_linux_deb.sh`.
- Debian package: `build/linux-lldtmp-2040/packages/echoes_1.1.0+2040_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2040`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `c12266581f3526fa8d6f6a772bf134b9ef6204f2a42f321abb161beceaa4d450`.
- `libapp.so` SHA-256: `9fee06e3a1fcd3f83443699473041c5ac60d22dde67befa862080ef0ce4463f8`.
- `.deb` SHA-256: `8633a2fd199b9eccbe93dbfd0daba052023fd98306de8ce2461013e50ea89786`.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2029`.
- Built with `--split-per-abi --target-platform android-arm64`; the APK contains only `arm64-v8a` native libraries.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,037 bytes.
- The user's local release signer was used; `apksigner verify` passed. Certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `6dd7ff15b501db779def63ed1b5aef10f30ebaa4ad8644c23600d3d24bf04970`.
- The local helper at `scripts/local/build_android_release_arm64.sh` stays excluded through `.git/info/exclude`. It starts at build number 27 when no prior output exists, then increments from the last local ARM64 APK on later runs. `ECHO_ANDROID_BUILD_NUMBER` can override that value.

## Remaining validation

Neither artifact was installed or launched. The Linux package still needs user validation for window controls, MPRIS, tray behavior, clean installation, and playback. Android navigation, playback, notification/lock-screen controls, and update-signature compatibility remain for device validation. The new widget tests were added but not run, per the user's request.
