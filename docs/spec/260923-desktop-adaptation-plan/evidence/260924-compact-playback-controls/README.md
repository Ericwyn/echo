# Compact desktop playback controls

## Change

- Source commit: `b0bc5800`.
- At the desktop player's compact widths, the tune menu now exposes volume adjustment, mute, shuffle, and playback-mode cycling. Previously, compact mode showed only mute and removed shuffle/repeat controls.
- The track summary narrows to 164 logical pixels when the main pane is below 720 pixels, leaving more width for the progress bar at the 840-pixel minimum window size.
- Android layout and controls are unchanged.

## Linux release build

- Flutter: 3.41.7.
- Build directory: `build/linux-lldtmp-2066`.
- Command: `flutter build linux --release --no-pub`.
- DEB: `build/linux-lldtmp-2066/packages/echoes_1.1.0+2055_amd64.deb`.
- DEB SHA-256: `74d9feab40b44be90a6ed55da5d86af9055962726cba3811b757bca4469f2bab`.
- Standalone bundle ZIP: `build/linux-lldtmp-2066/packages/echoes_1.1.0+2055_linux-x64-bundle.zip`.
- ZIP SHA-256: `9ac20a4b0262ea9ed6ac3d7315fa94cb6f904d77204939f0cb25c818cde31399`.

## Verification and remaining acceptance

- DEB metadata reports package `echoes`, version `1.1.0+2055`, architecture `amd64`, and dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `dpkg` version comparison confirmed `1.1.0+2055` is newer than `1.1.0+2054`.
- The release executable is ELF64 x86-64; all ZIP entries passed `unzip -t`.
- No Flutter tests or analyze were run, and the application was not launched, per the user's testing boundary.
- The compact popup, volume changes, mute, shuffle, playback-mode cycling, and progress layout at the minimum window size await the user's desktop check.
- Android was not rebuilt for this desktop-only control change. The current signed ARM64 APK remains versionCode `2054`; the local signing helper is ignored by Git and will produce the next ARM64 version when run.
