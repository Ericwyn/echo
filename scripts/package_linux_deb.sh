#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="$project_root/build/linux/x64/release/bundle"
desktop_file="$project_root/packaging/linux/echoes.desktop"
icon_file="$project_root/assets/tray_icon.png"
output_dir="${1:-$project_root/build/linux/packages}"

if [[ ! -x "$bundle_dir/echoes" ]]; then
  echo "Missing Linux release bundle: $bundle_dir/echoes" >&2
  echo "Build it first with: flutter build linux --release --no-pub" >&2
  exit 1
fi

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
