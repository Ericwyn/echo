# Desktop queue interaction build evidence

Date: 2026-09-24

Source commit: `87b994e3`

Scope: add optional double-click activation to the shared pressable/song-row contract and enable it only in the desktop playback queue. The phone queue keeps its existing single-tap playback behavior. Linux and Android release builds only; neither artifact was installed or launched. Flutter tests and `flutter analyze` were not run, per the user's instruction.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and the real Ubuntu LLD 14 binary extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2043`.
- Debian package: `build/linux-lldtmp-2043/packages/echoes_1.1.0+2043_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2043`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `1010965e1e473f41e5d9101286dffc103892992a7a0f13962a023f56779a2922`.
- `libapp.so` SHA-256: `c80937cd6c3630c5e91481e13ddbc9197894254d57fb210e6e36175d35fd6741`.
- `.deb` SHA-256: `1b76e5509199a1b0b3de70c0aa53aa1bcafbf86180f430fcd6b1a9be6954db63`.
- `dpkg-deb` metadata, ELF architecture, and desktop-file validation passed.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2032`.
- Built with `--split-per-abi --target-platform android-arm64`; the APK contains only `arm64-v8a` native libraries.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,037 bytes.
- `apksigner verify` passed. Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `603e45d9efadc328aa7a4a4fb44cd999acb77ea55dd15cce155806f645749ef1`.

The machine-local APK helper remains excluded through `.git/info/exclude`. The new double-click regression definition was added but not executed. Ubuntu queue interaction, long-queue performance, and Android device regression remain user validation items.
