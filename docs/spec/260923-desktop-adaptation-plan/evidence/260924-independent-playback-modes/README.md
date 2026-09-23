# Independent shuffle and repeat modes

## Change

- Source commit: `c7455cf0`.
- `PlaybackCommands.setShuffleEnabled` and `setLoopMode` now change only their own state; the desktop bar has separate shuffle and repeat controls. The mobile `cyclePlaybackMode` presets remain available.
- Linux MPRIS `Shuffle` and `LoopStatus` property writes now route to separate commands. Shuffle with repeat off stops at the end of the shuffled queue; repeat-all starts a new shuffled round; repeat-one repeats the current entry.
- Preferences use `playback_modes_v2` for independent values and continue mirroring the legacy combined `playback_mode`. Existing installs migrate their old combined preference. Playback session snapshots also save both values and still restore older sessions.
- Added regression definitions for MPRIS property routing, independent state updates, repeat-off shuffle completion, preference migration, and session restoration. They were not run.

## Linux release build

- Flutter: 3.41.7.
- Build directory: `build/linux-lldtmp-2068`.
- DEB: `build/linux-lldtmp-2068/packages/echoes_1.1.0+2057_amd64.deb`.
- DEB SHA-256: `b0fed7fee907b705b032a29f118ba695ac9c5655f0855fb265c81abd7a0b0728`.
- Standalone bundle ZIP: `build/linux-lldtmp-2068/packages/echoes_1.1.0+2057_linux-x64-bundle.zip`.
- ZIP SHA-256: `e882c05669b15c07e5813113ed8c3a5877ae52c296d9a1c909a72d3429c29573`.
- DEB metadata: `echoes`, version `1.1.0+2057`, architecture `amd64`, dependencies `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `dpkg` confirms 2057 is newer than 2056; the release executable is ELF64 x86-64; all ZIP entries passed `unzip -t`.

## Android release build

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Package/version: `com.az1n.echoes`, version name `1.1.0`, versionCode `2055`.
- ABI: `arm64-v8a` only.
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`.
- APK SHA-256: `a24959dfbeb366f2b803beb982a4886e2cbd952f7d48287584c3973b2626583c`.
- The local signing helper advanced its ignored version state to `2055`; the next ARM64 APK build defaults to `2056`.

## Remaining verification

- No Flutter tests or analyze were run. Neither package was installed or launched.
- The user should verify GNOME MPRIS changes to Shuffle and LoopStatus in both orders, track completion behavior for repeat-off/all/one, and Android queue/background controls after installing the APK.
