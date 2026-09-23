# Shared player layer build evidence

Date: 2026-09-24

Source commit: `a79f7210`

Scope: compile the shared playback controls and song action contract on Linux and Android. Builds only; no app launch, installation, Flutter tests, or `flutter analyze` were performed.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2038`.
- Release bundle compiled, then packaged with `scripts/package_linux_deb.sh`.
- Debian package: `build/linux-lldtmp-2038/packages/echoes_1.1.0+2038_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2038`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `1efcd0e119a9133c6745f7d8cf63d5900da7e448348df568315cbf258ea91c1f`.
- `libapp.so` SHA-256: `c81c39ebc99439c1e501b5888001cd898e21ad4ed19b4de4a6287a5cad15eb2c`.
- `.deb` SHA-256: `90755d9d53581e76265040a7ff4b78c56abda3fd602e1f56f389ec47f5d1e59b`.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2027`.
- Built with `--split-per-abi --target-platform android-arm64`; the APK contains only `arm64-v8a` native libraries.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,037 bytes.
- The user's local release signer was used; `apksigner verify` passed. Certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `06de49696f6ec05ffb9d9bd196c2639a23b59e42c2d6e4f48420e9791e8d0135`.
- The local helper at `scripts/local/build_android_release_arm64.sh` stays excluded through `.git/info/exclude`. It starts at build number 27 for the reported installed code 2026, then increments from the last local ARM64 APK on later runs. `ECHO_ANDROID_BUILD_NUMBER` can override that value.

## Remaining validation

Neither artifact was installed or launched. The Linux package still needs user validation for window controls, MPRIS, tray behavior, clean installation, and playback. Android navigation, playback, notification/lock-screen controls, and update-signature compatibility remain for device validation. The new widget tests were added but not run, per the user's request.
