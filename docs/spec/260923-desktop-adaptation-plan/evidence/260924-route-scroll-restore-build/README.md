# Route scroll restoration build — 2026-09-24

Source commit: `685ea3db` (includes `1de36904`).

The route-local `PageStorageBucket` can now restore scroll positions after desktop forward navigation rebuilds a page. Stable keys were added to search results, settings pages, download pages, album/playlist details, library editing, song metadata editing, and offline task status. The same widgets are shared with Android.

## Linux release

- Flutter 3.41.7; fresh build directory: `build/linux-lldtmp-2056/`.
- Debian package: `build/linux-lldtmp-2056/packages/echoes_1.1.0+2053_amd64.deb` (18,285,656 bytes).
- Package metadata: `echoes`, version `1.1.0+2053`, architecture `amd64`; dependency metadata inspected with `dpkg-deb -I`.
- Bundle executable SHA-256: `3360cdb2e791d9a65e2f2387ae428fdae0749061a1f80a4d0ca380d3a8b098e9`.
- `libapp.so` SHA-256: `6c0a2778cb59754aab505cb78d30c4c95bc3005b3212b26a3c1b1433ed69ec23`.
- `.deb` SHA-256: `d58f35c216d466700a5c7f3c51bf30672ad6462e90ca92330b6f1e378d6821b5`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (29,741,141 bytes).
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2046`.
- ABI: `arm64-v8a` only; `apksigner verify` passed.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `c75a4cc44c69e2aa91125f16b5eb32117504be92e0ebf3e47ed1b0009a1eaa2d`.

The machine-local shortcut is `scripts/local/build_android_release_arm64.sh`. It is executable, passes `bash -n`, and is excluded by `.git/info/exclude`; it contains local signing file locations and is not tracked or included in commits. Normal local use increments from the APK already in the build output and verifies the package, ABI, version code, and signing certificate.

## Verification limits

`dart format`, `git diff --check`, Linux release compilation, Debian metadata inspection, APK package/ABI inspection, and APK signature verification passed. No Flutter tests or `flutter analyze` were run. Neither artifact was installed or launched; desktop route restoration and Android behavior remain for user testing.
