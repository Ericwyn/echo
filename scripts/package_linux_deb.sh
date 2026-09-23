#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Allows packaging a bundle built with a non-default Flutter build directory.
bundle_dir="${ECHO_LINUX_BUNDLE_DIR:-$project_root/build/linux/x64/release/bundle}"
desktop_file="$project_root/packaging/linux/echoes.desktop"
icon_file="$project_root/assets/tray_icon.png"
output_dir="${1:-$project_root/build/linux/packages}"

if [[ ! -x "$bundle_dir/echoes" ]]; then
  echo "Missing Linux release bundle executable: $bundle_dir/echoes" >&2
  echo "Build it first with: flutter build linux --release --no-pub" >&2
  exit 1
fi
if ! command -v zip >/dev/null 2>&1; then
  echo "Missing required packaging tool: zip" >&2
  exit 1
fi

# A Flutter Linux bundle needs its engine, app, native plugins, ICU data and
# compiled Flutter assets. Checking only `echoes` can produce an installable
# but unusable Debian package when the caller points at an incomplete bundle.
required_bundle_files=(
  "lib/libapp.so"
  "lib/libflutter_linux_gtk.so"
  "lib/libmedia_kit_libs_linux_plugin.so"
  "lib/libscreen_retriever_linux_plugin.so"
  "lib/libsqlite3_flutter_libs_plugin.so"
  "lib/libtray_manager_plugin.so"
  "lib/liburl_launcher_linux_plugin.so"
  "lib/libwindow_manager_plugin.so"
  "lib/native_assets.json"
  "data/icudtl.dat"
  "data/flutter_assets/AssetManifest.bin"
  "data/flutter_assets/FontManifest.json"
  "data/flutter_assets/NOTICES.Z"
  "data/flutter_assets/version.json"
  "data/flutter_assets/assets/tray_icon.png"
)
for relative_path in "${required_bundle_files[@]}"; do
  if [[ ! -s "$bundle_dir/$relative_path" ]]; then
    echo "Incomplete Linux release bundle: missing $relative_path" >&2
    exit 1
  fi
done

version="$(sed -n 's/^version:[[:space:]]*//p' "$project_root/pubspec.yaml" | head -n1)"
if [[ -z "$version" || ! "$version" =~ ^[0-9A-Za-z.+:~_-]+$ ]]; then
  echo "Invalid Debian package version from pubspec.yaml: $version" >&2
  exit 1
fi

architecture="$(dpkg --print-architecture)"
if [[ "$output_dir" != /* ]]; then
  output_dir="$project_root/$output_dir"
fi
mkdir -p "$output_dir"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/echoes-deb.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
package_root="$work_dir/root"

install -d \
  "$package_root/DEBIAN" \
  "$package_root/opt/echoes" \
  "$package_root/usr/share/applications" \
  "$package_root/usr/share/icons/hicolor/192x192/apps"
cp -a "$bundle_dir/." "$package_root/opt/echoes/"
install -m 0644 "$desktop_file" \
  "$package_root/usr/share/applications/echoes.desktop"
install -m 0644 "$icon_file" \
  "$package_root/usr/share/icons/hicolor/192x192/apps/echoes.png"

cat > "$package_root/DEBIAN/control" <<EOF
Package: echoes
Version: $version
Section: sound
Priority: optional
Architecture: $architecture
Maintainer: Echoes Project
Depends: libgtk-3-0, libayatana-appindicator3-1, libmpv1
Description: Cross-platform music player
 Echoes is a Flutter music player for Android and Linux.
EOF

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$package_root/usr/share/applications/echoes.desktop"
fi

package_path="$output_dir/echoes_${version}_${architecture}.deb"
dpkg-deb --root-owner-group --build "$package_root" "$package_path"
echo "Created $package_path"

# Ship the raw Flutter bundle alongside the installable Debian package. Build
# to a temporary path so reruns cannot retain stale entries from an older ZIP.
bundle_zip_path="$output_dir/echoes_${version}_linux-x64-bundle.zip"
bundle_zip_tmp="$work_dir/linux-x64-bundle.zip"
(
  cd "$bundle_dir"
  zip -qr "$bundle_zip_tmp" .
)
mv -f "$bundle_zip_tmp" "$bundle_zip_path"
echo "Created $bundle_zip_path"
