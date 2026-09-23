# Playback queue index build

## Change

Commit `c4bd0b6e` clamps the requested start index in `PlaybackCommands.playQueue`
to the valid queue range before reading the selected song. A recovery test was
added for negative and past-the-end indexes; it was not run by request. The
shared command integration from `46453bb2` / `b12aa608` remains in this build.

## Linux release

- Build directory: `build/linux-lldtmp-2063`
- Debian package: `echoes_1.1.0+2053_amd64.deb`
- Package: `echoes`, version `1.1.0+2053`, architecture `amd64`
- Executable SHA-256: `e1eb6488780e2d70fed09976c920b12e7fd7d018439adfc0beeeb9de35cf4ec8`
- `libapp.so` SHA-256: `d3a1af2c5742bb4ecbc4b1705d26998a043a4174085cab1171ec24772cfe24db`
- DEB SHA-256: `955e3c8f222be6582a4ae9a9993fb5b700136cc61704401c5b06e413ed4a8ffd`
- Standalone bundle ZIP: `echoes_1.1.0+2053_linux-x64-bundle.zip`
- Bundle ZIP SHA-256: `5de9a27a5d1be3e15e3540d2750cb9323acbfd52c3f365e9e16c91dfd88f2bbd`
- Bundle ZIP size: `22,690,948` bytes; 38 files

`dpkg-deb` metadata was checked and the standalone ZIP passed `unzip -t`.
Neither artifact was installed or launched.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.az1n.echoes`, version name `1.1.0`, version code `2054`
- ABI: `arm64-v8a` only
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`
- APK SHA-256: `26ce4001832b034a515392661eafa0ddda4c80b08b2774c9c85f0b475f4d1380`
- Size: `29,741,141` bytes

The ignored local ARM64 helper signed the APK and checked the package, version,
ABI, and certificate. The APK was not installed or launched.

## Not run

Flutter tests, `flutter analyze`, Android device checks, GNOME interaction,
clean-install validation, and performance sampling were not run. Windows CI
remains deferred.
