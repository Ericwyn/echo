# Library management return navigation — 2026-09-24

Source commit: `a6ee5e65`.

## Change

Adding a music library now marks the login route as an add-library flow. After successful authentication, the app pops that route and reveals the page that launched it, preserving the desktop settings/history stack and the mobile drawer route. Editing or deleting a library returns through the nearest Navigator; a direct editor entry without a previous page falls back to Music Flow.

Added widget regression cases for nested-Navigator return and the no-previous-route fallback. They were not run per the user's instruction.

## Linux release

- Flutter 3.41.7; fresh CMake build directory: `build/linux-lldtmp-2053/`.
- Debian package: `build/linux-lldtmp-2053/packages/echoes_1.1.0+2051_amd64.deb`.
- Metadata: package `echoes`, version `1.1.0+2051`, architecture `amd64`; bundle preflight and package metadata checks passed.
- Bundle executable SHA-256: `1e914b6f79795659b3e83c3a99e9b5b4ce33b588caf70d86107f7d36ce0a09e2`.
- `libapp.so` SHA-256: `c3a769a8d67148006a5c9384deb2b2f13521766ce25bbe6072e708f5f26fa0b5`.
- `.deb` SHA-256: `bf507248f6d90ef46212cf10067f751921a9d731372ee9c53b573142be10ae28`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2042`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `0e9ad83fc5e145fb429bdca1fc19fdf80030701d28ef60a3ff7c0c6b471c67f4`.

Both release builds passed. Neither artifact was installed or launched. No Flutter tests or `flutter analyze` were run. Desktop add/edit return behavior and Android add-library behavior remain for manual verification.
