# Shared song actions build evidence

Date: 2026-09-24

Source commit: `f8b026cb`

Scope: move built-in song action construction into `SongActionFactory`. `SongOptionsSheet` now presents those actions and owns sheet dismissal; factory callbacks execute through the app's root `ProviderContainer`, and the sheet provides the playlist picker callback. This also removes the old double-dismiss path where both a built-in action and its row attempted to pop the sheet. Linux and Android release builds only; neither artifact was installed or launched. Flutter tests and `flutter analyze` were not run, per the user's instruction.

## Linux Ubuntu package

- Flutter 3.41.7, Ubuntu 22.04 x86_64, system Clang 14, and real Ubuntu LLD 14 extracted under `/tmp`.
- Fresh CMake build directory: `build/linux-lldtmp-2045`.
- Debian package: `build/linux-lldtmp-2045/packages/echoes_1.1.0+2045_amd64.deb`.
- Package metadata: name `echoes`, version `1.1.0+2045`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- Executable SHA-256: `0f5bd2390295be2cbef9fe52fe794044715aa1dd2da260c1add3e4a971b377ab`.
- `libapp.so` SHA-256: `6bfd094a9da526990064519587316b1e7448487dde56eed06c6d9e0aa3841c49`.
- `.deb` SHA-256: `3288dc4ffd72889b3cf4c5804f86e56355851665c64062b2ab2766a34212082a`.
- Package metadata, ELF architecture, and desktop-file validation passed.

## Android arm64 APK

- Package: `com.az1n.echoes`; version name `1.1.0`; version code `2034`.
- Built with `--split-per-abi --target-platform android-arm64`; only `arm64-v8a` native libraries are included.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 29,741,141 bytes.
- `apksigner verify` passed. Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `20ef29e0ab78aa5081b5df66c7a0c04cbb7022e4fb5d5f4eb0f19b0995bd3b7b`.

The local Android helper remains excluded through `.git/info/exclude`. The new host-action and single-dismiss regression definition was added but not run. Action selection, navigation/playlist callbacks, and Android playback behavior remain device validation items.
