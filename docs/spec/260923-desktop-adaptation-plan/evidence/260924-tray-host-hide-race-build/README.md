# Tray-host loss during close build — 2026-09-24

Source commit: `d6bb46f5`.

When close-to-tray starts with an available StatusNotifier host, the host may disappear while `windowManager.hide()` is still pending. The lifecycle service now rechecks availability after the hide completes; if the host vanished, it shows the window and minimizes it so the taskbar remains a recovery path. Existing host-loss handling still restores a window that was already hidden.

## Linux release

- Flutter 3.41.7; fresh build directory: `build/linux-lldtmp-2058/`.
- Debian package: `build/linux-lldtmp-2058/packages/echoes_1.1.0+2053_amd64.deb` (18,286,302 bytes).
- Metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`; package preflight and `dpkg-deb -I` inspection passed.
- Bundle executable SHA-256: `a7aa9bd28d6474271b3cd90084d0867a66be25a0d00c6f1b64042dd2dcaa3a75`.
- `libapp.so` SHA-256: `4e213db33f8316e5b1ed04f51a8014582051fa363314a8eb640b98d2583aa635`.
- `.deb` SHA-256: `3a5b7363c291492ebfda10cb165eea95f34f16a2daa50e14001e54629e8ea5ab`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (29,741,141 bytes).
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2048`.
- ABI: `arm64-v8a` only; release signature and package metadata verified by the local build helper.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `00bfd0772d6d88d126b6c9690af753b49be2dc44537967adb8a49f251aba552b`.

Neither artifact was installed or launched. No Flutter tests or `flutter analyze` were run. The host-disappearance timing and taskbar recovery path still require manual Ubuntu validation.
