# Linux bundle packaging preflight — 2026-09-24

Application source: `14f39032`.
Debian packaging script: `b8e3cd00`.

## Change

`scripts/package_linux_deb.sh` now rejects incomplete Flutter Linux bundles before assembling a Debian package. It checks the executable, Flutter app/engine libraries, this project's Linux plugin shared libraries, native-assets manifest, ICU data, asset/font manifests, license notices, version metadata, and tray icon. The required plugin files are explicit because the Flutter SDK is pinned and these plugins are part of this app's Linux runtime.

## Verification

- `bash -n scripts/package_linux_deb.sh` completed successfully.
- Packaged the existing full release bundle at `build/linux-lldtmp-2047/linux/x64/release/bundle/` using the updated script.
- Debian metadata: package `echoes`, version `1.1.0+2046`, architecture `amd64`; dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- Package: `build/linux-lldtmp-2047/packages/echoes_1.1.0+2046_amd64.deb`.
- SHA-256: `e85f699013eb962bb4d10e1966413d416eba3b903aacd38a75e897da84ca12f3`.

No application was installed or launched. No Flutter tests or `flutter analyze` were run. Clean-system installation, actual playback, and upgrade retention remain for user verification.
