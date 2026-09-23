# Linux MPRIS contract build — 2026-09-24

Source commit: `54207f92`.

## Changes

- `LoopStatus` now reports the repeat mode independently of the MPRIS `Shuffle` property.
- MPRIS track IDs hash an unambiguous serialized `(libraryId, entryId)` tuple with SHA-256. This avoids separator ambiguity and reduces stale `SetPosition` accepting a different track due to a short-hash collision.
- Regression cases cover repeat/shuffle reporting and stale track IDs from ambiguous library/entry pairs. They were not run.

## Linux release

- Flutter 3.41.7; fresh build directory: `build/linux-lldtmp-2057/`.
- Debian package: `build/linux-lldtmp-2057/packages/echoes_1.1.0+2053_amd64.deb` (18,285,260 bytes).
- Metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`; package preflight and `dpkg-deb -I` inspection passed.
- Bundle executable SHA-256: `142677f86f614c886992b913e32fc06b065b8762e0df4f799611cfe03e23275c`.
- `libapp.so` SHA-256: `9998d54bcfb2348b2dc30c4d43537b50864b4b52b766e48863c2e6892fa93632`.
- `.deb` SHA-256: `aa9425eb00b6b594e515b638ea894ce30bb40c789ef849bf2caa1698bf5fd20a`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (29,741,141 bytes).
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2047`.
- ABI: `arm64-v8a` only; release signature and package metadata verified by the local build helper.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `08e74d6e98d2a966db2d77b598da3ea6ff53b1c40ed45013be8dd0ebacf8a8f3`.

Neither artifact was installed or launched. No Flutter tests or `flutter analyze` were run. Ubuntu MPRIS seek, LoopStatus/Shuffle behavior, and Android device behavior remain for manual verification.
