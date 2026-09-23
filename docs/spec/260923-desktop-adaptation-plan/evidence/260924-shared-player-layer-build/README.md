# Shared player layer build evidence

Date: 2026-09-24

Source commit: `8149800f`

Scope: compile the shared playback controls, song action contract, and `PlaybackCommands` UI integration across Flutter controls, queue, shortcuts, Linux tray, and synced lyrics on Linux and Android. Builds only; no app launch, installation, Flutter tests, or `flutter analyze` were performed.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2041`.
- Release bundle compiled, then packaged with `scripts/package_linux_deb.sh`.
- Debian package: `build/linux-lldtmp-2041/packages/echoes_1.1.0+2041_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2041`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `54e40bcf90567b5f7da2b7bfedd5c3288dc1c5cc288a606fcd5ada92179f215d`.
- `libapp.so` SHA-256: `28f7aea71f66042533cfe1f7ae782562dfd037a08adb2e127f6016f69344f6a9`.
- `.deb` SHA-256: `78d4dc7ac8b27be530eada228fa7d18da4fafdc78600c9b3563d32bd35c1fe0d`.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2030`.
- Built with `--split-per-abi --target-platform android-arm64`; the APK contains only `arm64-v8a` native libraries.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,037 bytes.
- The user's local release signer was used; `apksigner verify` passed. Certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `2ad4b2a4d8918cf734576017eb7d65d4858dd440bf5299208d02e38ecfed8a06`.
- The local helper at `scripts/local/build_android_release_arm64.sh` stays excluded through `.git/info/exclude`. It starts at build number 27 when no prior output exists, then increments from the last local ARM64 APK on later runs. `ECHO_ANDROID_BUILD_NUMBER` can override that value.

## Remaining validation

Neither artifact was installed or launched. The Linux package still needs user validation for window controls, MPRIS, tray behavior, clean installation, and playback. Android navigation, playback, notification/lock-screen controls, and update-signature compatibility remain for device validation. The new widget tests were added but not run, per the user's request.
