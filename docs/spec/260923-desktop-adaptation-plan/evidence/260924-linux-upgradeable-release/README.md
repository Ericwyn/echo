# Linux upgradeable release

## Build

- Source commit: `5f3ed83b` (advances the package build version after Linux lifecycle work in `9abb3e09`).
- Build directory: `build/linux-lldtmp-2065` (fresh Flutter/CMake build directory).
- Command: `flutter build linux --release --no-pub`, then `scripts/package_linux_deb.sh` and standalone bundle packaging.
- Debian package: `build/linux-lldtmp-2065/packages/echoes_1.1.0+2054_amd64.deb`
- Metadata: package `echoes`, version `1.1.0+2054`, architecture `amd64`.
- SHA-256: `74906068a616b764dc939f6594ed218e00309addb21c39cc57cee8bfe24adb9e`
- Standalone bundle: `build/linux-lldtmp-2065/packages/echoes_1.1.0+2054_linux-x64-bundle.zip`
- Bundle ZIP SHA-256: `cafaa42f48442e8660ad692ef6a942ba99dfbc1cd0fa5311d202f2c36ccc0993`

## Verification

- `dpkg-deb -f` confirmed `echoes` / `1.1.0+2054` / `amd64` and dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `dpkg --compare-versions 1.1.0+2054 gt 1.1.0+2053` succeeded, so the new DEB is ordered as an upgrade from the previous package.
- The app executable and media-kit plugin are ELF64 x86-64; `ldd` resolved the app executable's direct dependencies on this build host. The media-kit plugin loads system libmpv at runtime, covered by the `libmpv1` package dependency.
- Every ZIP entry passed `unzip -t`.
- No Flutter tests or analyze were run. The DEB was not installed and the app was not launched; clean Ubuntu install, playback, and user-data preservation remain pending.
- No Android APK was rebuilt in this release. The local ARM64 helper still has versionCode `2054` recorded and will produce `2055` on its next run because it passes an explicit Flutter build number.
