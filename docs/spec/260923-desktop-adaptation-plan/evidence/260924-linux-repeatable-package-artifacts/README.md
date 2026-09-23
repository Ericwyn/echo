# Repeatable Linux package artifacts

## Change

- Linux package workflow commit: `818239ea`.
- `scripts/package_linux_deb.sh` now emits both the installable Debian package and a standalone ZIP containing the exact Flutter bundle. It writes the ZIP to a temporary path before replacing the final archive, avoiding stale entries on reruns.
- Linux release CI uploads the DEB and bundle ZIP from the same package directory. PR checks install the `zip` tool required by the package script.
- App source commit: `24e5319e`; Flutter bundle build directory: `build/linux-lldtmp-2069`; pubspec version: `1.1.0+2058`.

## Package verification

- Package script was run from the committed `818239ea` against the release bundle and wrote both files to `build/linux-lldtmp-2072/packages/`.
- DEB: `echoes_1.1.0+2058_amd64.deb`.
- DEB SHA-256: `8dd62dd8b7ceeaf736aa67d845f4fe763991e5ce16a496b2a195f25095028486`.
- Standalone bundle ZIP: `echoes_1.1.0+2058_linux-x64-bundle.zip`.
- ZIP SHA-256: `884489b3c06823e6b116be2fe657661d72b9112af62eab9c8d253a898d74d340`.
- DEB metadata: `echoes`, version `1.1.0+2058`, architecture `amd64`, dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, and `libmpv1`.
- `dpkg` confirmed 2058 is newer than 2057. The ZIP contains 38 entries and passed `unzip -t`; the executable is ELF64 x86-64.
- `bash -n` passed for the package script. Both modified workflow YAML files parsed successfully.

## Remaining verification

- No Flutter tests/analyze were run. The application was not installed or launched.
- The GitHub workflows were not dispatched. Ubuntu installation, application menu identity, clean-machine runtime dependencies, and actual playback remain part of manual release acceptance.
