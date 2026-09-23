# Playback command unification build

## Change

Commits `46453bb2` and `b12aa608` extend the shared `PlaybackCommands` contract
with queue replacement, preview playback, queue insertion, and batch queue
append. Browse, search, downloads, Explore, album/artist/playlist/favorite
views, album actions, and song actions now send those intents through
`playbackCommandsProvider`. Favorite mutation remains in its song-action
service; library-switch and metadata-refresh lifecycle operations remain in
their dedicated paths.

Existing widget tests use `TestPlayerNotifier` to record queue operations; the
new command paths were not run under tests or analysis by request.

## Linux release

- Build directory: `build/linux-lldtmp-2062`
- Debian package: `echoes_1.1.0+2053_amd64.deb`
- Package: `echoes`, version `1.1.0+2053`, architecture `amd64`
- Executable SHA-256: `1e4a96a87e1f69264a169b437a127326c197447982bccdd86fa11929adbc1e53`
- `libapp.so` SHA-256: `60abaa598043b242ae93c375021a2a2118f10c45f275142dea96c21854467031`
- DEB SHA-256: `f7d6e9f3ffe9bd44a59841628ef322bbe0aca17526e7341deb0b15c8cfdc742f`
- Standalone bundle ZIP: `echoes_1.1.0+2053_linux-x64-bundle.zip`
- Bundle ZIP SHA-256: `7e06b94cf5ba7128b8ffc964ef5fff65838267cba1815d1aeade132e715bcbc9`
- Bundle ZIP size: `22,690,989` bytes; 38 files

`dpkg-deb` metadata was checked and the standalone ZIP passed `unzip -t`.
Neither artifact was installed or launched.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.az1n.echoes`, version name `1.1.0`, version code `2053`
- ABI: `arm64-v8a` only
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`
- APK SHA-256: `3626dfd31c0b7bd364618d78e23cfc6b04afbc8970110188af55f16506605ed5`
- Size: `29,741,141` bytes

The ignored local ARM64 helper signed the APK and checked the package, version,
ABI, and certificate. The APK was not installed or launched.

## Not run

Flutter tests, `flutter analyze`, Android device checks, GNOME interaction,
clean-install validation, and performance sampling were not run. Windows CI
remains deferred.
