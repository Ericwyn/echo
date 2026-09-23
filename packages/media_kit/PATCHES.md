# Local `media_kit` compatibility patch

This directory vendors the runtime `lib/` and web asset from upstream
[`media_kit` 1.2.6](https://pub.dev/packages/media_kit/versions/1.2.6), with its
MIT license retained. The root `pubspec.yaml` overrides the hosted package so
the Linux build can run against Ubuntu 22.04's system `libmpv` 0.34.

The patch in `lib/src/player/native/player/real.dart` keeps Linux network
buffering in the existing bounded memory cache and omits the unused
`subs-fallback` option. Ubuntu 22.04's `libmpv` has no `subs-fallback` option,
and disk caching requires an explicit cache directory there. This application
does not expose MPV subtitle playback or configure an MPV disk-cache directory.
Other platforms retain upstream defaults.

When upgrading `media_kit`, reapply and recheck this compatibility patch against
the new upstream implementation. Keep upstream copyright and license notices
in the vendored source files.
