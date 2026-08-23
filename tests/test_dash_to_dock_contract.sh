#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

grep -Fq 'ENABLE_GNOME_EXTENSIONS="true"' "$ROOT/config/gnome.conf"
grep -Fq 'ENABLE_DASH_TO_DOCK="true"' "$ROOT/config/gnome.conf"
grep -Fq 'DASH_TO_DOCK_PACKAGE="gnome-shell-extension-dash-to-dock"' "$ROOT/config/gnome.conf"
grep -Fq 'DASH_TO_DOCK_UUID="dash-to-dock@micxgx.gmail.com"' "$ROOT/config/gnome.conf"
grep -Fq 'PRESERVE_DASH_TO_DOCK_UPSTREAM_DEFAULTS="true"' "$ROOT/config/gnome.conf"
grep -Fxq 'gnome-shell-extension-dash-to-dock' "$ROOT/manifests/packages-gnome-extensions.txt"
grep -Fq 'packages-gnome-extensions.txt' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'gnome-extensions enable' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'State: ENABLED' "$ROOT/modules/gnome/24_gnome_extensions.sh"

! grep -RInE --exclude-dir=.git '(extensions\.gnome\.org.*curl|curl.*extensions\.gnome\.org|wget.*extensions\.gnome\.org|unzip.*gnome-shell/extensions)' "$ROOT/modules/gnome" "$ROOT/scripts" || {
  echo 'Dash to Dock must come from Fedora RPM, not unmanaged extension downloads' >&2
  exit 1
}

echo 'Dash to Dock contract: PASS'
