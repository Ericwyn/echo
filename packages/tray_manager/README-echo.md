This is `tray_manager` 0.5.3 with a small Linux-only AppIndicator change.

- The first context-menu item receives `SecondaryActivate`, so middle-click
  invokes Echoes' existing "Show Echo" action on older Ubuntu libraries.
- When a newer libayatana-appindicator exposes its `activate` signal, forward
  it to the existing Dart `onTrayIconMouseDown` listener.

The Dart API and macOS/Windows implementations are unchanged. The upstream
package is MIT licensed; see `LICENSE`.
