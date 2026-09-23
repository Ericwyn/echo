# Shared player layer build evidence

Date: 2026-09-24

Source commit: `7e0c991b`

Scope: compile the shared playback controls and song action contract on Linux and Android. Builds only; no app launch, installation, Flutter tests, or `flutter analyze` were performed.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2039`.
- Release bundle compiled, then packaged with `scripts/package_linux_deb.sh`.
- Debian package: `build/linux-lldtmp-2039/packages/echoes_1.1.0+2039_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2039`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `3bffc3fe06a5f547235ff83db85018a23f113764722d70aed61d7b53e6012e26`.
- `libapp.so` SHA-256: `e611c69d5d0dfb07bd54b164a0f93536634ffa36883d4dcd552c0ba3856777f4`.
- `.deb` SHA-256: `1bec76debeab85de7b82105fc96b63d5763ef3d0efd3c7410125cc84c47237a6`.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2028`.
- Built with `--split-per-abi --target-platform android-arm64`; the APK contains only `arm64-v8a` native libraries.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,037 bytes.
- The user's local release signer was used; `apksigner verify` passed. Certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `f6b35292fc65cf2a26d311d4436be2e44a5219f0fc2f02a7e3032be054ac5580`.
- The local helper at `scripts/local/build_android_release_arm64.sh` stays excluded through `.git/info/exclude`. It starts at build number 27 when no prior output exists, then increments from the last local ARM64 APK on later runs. `ECHO_ANDROID_BUILD_NUMBER` can override that value.

## Remaining validation

Neither artifact was installed or launched. The Linux package still needs user validation for window controls, MPRIS, tray behavior, clean installation, and playback. Android navigation, playback, notification/lock-screen controls, and update-signature compatibility remain for device validation. The new widget tests were added but not run, per the user's request.
