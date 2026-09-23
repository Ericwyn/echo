# Desktop fullscreen build evidence

Date: 2026-09-24

Source commit: `9cbc98fa`

Scope: add an optional native fullscreen control to the desktop playback workspace, exit fullscreen before closing the workspace on Escape, and keep fullscreen dimensions out of the saved normal window size. The existing lyrics/queue components stay mounted. Android does not expose the native fullscreen action. Linux and Android release builds only; neither artifact was installed or launched. Flutter tests and `flutter analyze` were not run, per the user's instruction.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and real Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2044`.
- Debian package: `build/linux-lldtmp-2044/packages/echoes_1.1.0+2044_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2044`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `5bace48849f7779f3a200396b9b582213b74e0dff6c843b83adb168031651422`.
- `libapp.so` SHA-256: `44c6495d2fbfc8943e8508ffb41f0863eea5f145ad69a2d3269e4da597aecf46`.
- `.deb` SHA-256: `a53fc7ae559a72f60908bfc64246e70b84065362e2e58f2afcefdecc7ca5492d`.
- Package metadata, ELF architecture, and desktop-file validation passed.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2033`.
- Built with `--split-per-abi --target-platform android-arm64`; only `arm64-v8a` native libraries are included.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,141 bytes.
- `apksigner verify` passed. Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `a174cafa1a0c92ad5063c6c299df504541c1023c9d6210f94b49d4d1890c5d48`.

The Echo-drawn title strip remains visible in fullscreen; confirm its GNOME behavior and window-size restoration manually. Fullscreen/escape/window-state regression definitions were added but not executed. Wayland, Android device behavior, clean installation, and Linux performance remain unverified.
