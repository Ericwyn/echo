# Compact desktop playback menu

## Change

- Source commit: `5f0f429d` (following the compact-control layout in `b0bc5800`).
- The compact desktop bar keeps volume adjustment, mute, shuffle, and playback-mode cycling in an anchored `MenuAnchor`; the volume slider remains an enabled, independently accessible control inside the menu.
- At a 608-pixel main pane (840-pixel app width with the expanded sidebar), the track summary narrows to 164 pixels to preserve space for progress seeking.
- Android UI and playback behavior are unchanged.

## Linux release build

- Flutter: 3.41.7.
- Build directory: `build/linux-lldtmp-2067`.
- Command: `flutter build linux --release --no-pub`.
- DEB: `build/linux-lldtmp-2067/packages/echoes_1.1.0+2056_amd64.deb`.
- DEB SHA-256: `fc9a06eaa2bc093a10afbf725fc0585c92fce1899b47af61c4ed314d7369ecdb`.
- Standalone bundle ZIP: `build/linux-lldtmp-2067/packages/echoes_1.1.0+2056_linux-x64-bundle.zip`.
- ZIP SHA-256: `c125bb72c9708ea3aaf79e9167236c30d2312f6bdc7692f5dd4e9d5f24902fc0`.

## Verification and remaining acceptance

- DEB metadata reports package `echoes`, version `1.1.0+2056`, architecture `amd64`, and dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `dpkg` version comparison confirmed `1.1.0+2056` is newer than `1.1.0+2055`.
- The release executable is ELF64 x86-64; all ZIP entries passed `unzip -t`.
- No Flutter tests or analyze were run, and the application was not launched, per the user's testing boundary.
- The user should verify the anchored menu, slider dragging/keyboard semantics, mute, shuffle, mode cycling, and progress layout at the minimum window size.
- Android was not rebuilt for this desktop-only change. The current signed ARM64 APK remains versionCode `2054`; the ignored local helper will produce `2055` on its next run.
