# Clean Linux release build

## Scope

- Removed the project's existing `build/` directory (about 7.6 GB of old Linux and Android build artifacts).
- Rebuilt Linux release from an empty `build/` directory using Flutter 3.41.7, without launching the application.
- Raised `pubspec.yaml` from `1.1.0+2059` to `1.1.0+2060`, so the new DEB is upgradeable over the previous package.
- Fixed `scripts/package_linux_deb.sh` to check the actual clean-build `data/flutter_assets/NativeAssetsManifest.json`. The prior `lib/native_assets.json` check relied on a stale file left by earlier incremental builds; the current native-assets manifest contains an empty map.

## Artifacts and checks

- Raw bundle: `build/linux/x64/release/bundle/`.
- DEB: `build/linux/packages/echoes_1.1.0+2060_amd64.deb`, SHA-256 `b337215395589079fafb42d59e46115f8fbd3ca696cdb83a58c196b43e97d575`.
- Standalone ZIP: `build/linux/packages/echoes_1.1.0+2060_linux-x64-bundle.zip`, SHA-256 `001dde6f32658890d65f3db38aba0e5e09924c10e653b765a59774ab126779db`.
- Linux release build, package script, ZIP integrity, DEB metadata, `bash -n`, and `git diff --check` passed. The `build/` directory is now about 141 MB.
- The app was not installed or launched. Flutter widget tests/analyze and Ubuntu visual/window checks were not run.

The old Android APK in `build/` was removed with the requested cleanup. No Android APK was built in this pass.
