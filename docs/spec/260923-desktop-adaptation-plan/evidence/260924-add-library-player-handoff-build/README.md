# Add-library player handoff — 2026-09-24

Source commit: `67f62407`.

## Change

When adding a library from an authenticated session, the app now waits for server authentication to succeed, then saves and stops the outgoing library's player before persisting and activating the new library. The new row is initially stored inactive to avoid a transient two-active-library state. If persistence or activation fails, the partially saved inactive row is removed and the outgoing player's command binding/playback is restored. On success, the old notifier is invalidated so the new active library restores only its own playback session.

Regression cases were added for the preparation order, failed persistence rollback, and cleanup after activation failure. They were not run per the user's instruction.

## Linux release

- Flutter 3.41.7; fresh CMake build directory: `build/linux-lldtmp-2054/`.
- Debian package: `build/linux-lldtmp-2054/packages/echoes_1.1.0+2052_amd64.deb`.
- Metadata: package `echoes`, version `1.1.0+2052`, architecture `amd64`; bundle preflight and package metadata passed.
- Bundle executable SHA-256: `e6b189c5ce1b6f1bd26ec7d114938ed7e077761ce7f58cb96f2bd0b4b090dd34`.
- `libapp.so` SHA-256: `40e83b250dbc380e979cc3279954d77f8cda07ea84940b716a73339777e07139`.
- `.deb` SHA-256: `29715b8ae81432287418e431af6db55eabb842db8f3048053759fb8ea3bdd05b`.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, version code `2043`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `007e78cbd0139aaebfd8e034c7aa981859500a1a646a4223f8b7fc25a2dc3d93`.

Both release builds passed. Neither artifact was installed or launched. No Flutter tests or `flutter analyze` were run. Library addition while audio is playing, rollback after a failed write, and Android notification/lock-screen behavior remain for manual verification.
