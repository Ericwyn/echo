# Library deletion history build

## Change

Commit `cab6fe11` clears desktop forward history when returning from a route
whose library was deleted. The desktop navigator exposes this operation through
a desktop-only inherited scope; Android keeps the existing nearest-Navigator
return behavior. The delete flow invalidates the library list after deletion,
continues if playback-session cleanup fails, and leaves the deleted editor
instead of rethrowing an error into a stale route. A desktop navigation
regression test was added but was not run.

## Linux release

- Build directory: `build/linux-lldtmp-2061`
- Debian package: `echoes_1.1.0+2053_amd64.deb`
- Package: `echoes`, version `1.1.0+2053`, architecture `amd64`
- Executable SHA-256: `c30e034e4de92365d4b9f19a0d7a093500f72d3433c100396ffdd7c6d807ed5a`
- `libapp.so` SHA-256: `24d97824f28fa8dd58c6f977e00cbe7872c2ed43756dc2f0abe7edc9856c05cc`
- Package SHA-256: `1a2537c13606144a0b55c11d6bdffe04f5c486b8628f5792c68f5b58097af119`

The release bundle compiled and the Debian package metadata was checked. The
application was not installed or launched.

## Android ARM64 release

- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.az1n.echoes`, version name `1.1.0`, version code `2051`
- ABI: `arm64-v8a` only
- Release certificate SHA-256: `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`
- APK SHA-256: `4b53b3c8414ac701a950706aa783b6e5a416f503284bdf1c2bfbfc60463b2a77`
- Size: `29,741,141` bytes

The local ARM64 build helper signed the APK and verified package metadata,
version code, ABI, and certificate. It remains excluded through
`.git/info/exclude` because it contains this machine's signing-file paths.
The APK was not installed or launched.

## Not run

Flutter tests, `flutter analyze`, and interactive checks were not run. The user
will test the Linux and Android builds and perform desktop interaction checks.
Windows CI remains deferred.
