#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="$(<"$ROOT/VERSION")"
[[ "$(printf '%s\n%s\n' '0.12.0' "$version" | sort -V | head -n1)" == "0.12.0" ]]

# Fedora 44 does not package DING; the Golden profile pins GNOME Extensions v95/review 74408.
for expected in \
  'ENABLE_DESKTOP_ICONS_NG="true"' \
  'DING_UUID="ding@rastersoft.com"' \
  'DING_SOURCE_URL="https://extensions.gnome.org/review/download/74408.shell-extension.zip"' \
  'DING_REVIEW_ID="74408"' \
  'DING_VERSION="95"' \
  'DING_SHELL_VERSION="50"' \
  'DING_SCHEMA="org.gnome.shell.extensions.ding"' \
  'DING_DESKTOP_DIR_NAME="Bureau"' \
  'DING_SHOW_TRASH="true"' \
  'DING_SHOW_HOME="false"' \
  'DING_SHOW_VOLUMES="false"' \
  'DING_SHOW_NETWORK_VOLUMES="false"'; do
  grep -Fq "$expected" "$ROOT/config/gnome.conf"
done
if grep -Fxq 'gnome-shell-extension-desktop-icons-ng' "$ROOT/manifests/packages-gnome-extensions.txt"; then
  echo 'DING must not be declared as a Fedora RPM on Fedora 44' >&2
  exit 1
fi
grep -Fxq 'xdg-user-dirs' "$ROOT/manifests/packages-gnome.txt"
grep -Fq 'xdg-user-dirs-update --set DESKTOP' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq "gsettings --schemadir \"\$schema_dir\"" "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'show-trash' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'show-network-volumes' "$ROOT/modules/gnome/24_gnome_extensions.sh"

ding_installer="$ROOT/scripts/gnome/install-ding.sh"
grep -Fq 'https://extensions.gnome.org/review/download/74408.shell-extension.zip' "$ding_installer"
grep -Fq 'ding@rastersoft.com' "$ding_installer"
grep -Fq "curl --fail --location --proto '=https' --tlsv1.2" "$ding_installer"
grep -Fq "unzip -p \"\$zip\" metadata.json" "$ding_installer"
grep -Fq 'org.gnome.shell.extensions.ding.gschema.xml' "$ding_installer"
grep -Fq "glib-compile-schemas \"\$schema_dir\"" "$ding_installer"
grep -Fq 'review_id=74408' "$ding_installer"
grep -Fq 'site_version=95' "$ding_installer"
grep -Fq 'install-ding.sh' "$ROOT/modules/gnome/24_gnome_extensions.sh"

# Show Desktop Plus is pinned to the one GNOME-reviewed v8 artifact approved for GNOME 50.
for expected in \
  'ENABLE_SHOW_DESKTOP_PLUS="true"' \
  'SHOW_DESKTOP_PLUS_UUID="show-desktop-plus@attentivecoder"' \
  'SHOW_DESKTOP_PLUS_SOURCE_URL="https://extensions.gnome.org/review/download/70326.shell-extension.zip"' \
  'SHOW_DESKTOP_PLUS_REVIEW_ID="70326"' \
  'SHOW_DESKTOP_PLUS_VERSION="8"' \
  'SHOW_DESKTOP_PLUS_SHELL_VERSION="50"' \
  'SHOW_DESKTOP_PLUS_BUTTON_POSITION="left-end"' \
  'SHOW_DESKTOP_PLUS_LEFT_CLICK_ACTION="toggle-desktop"' \
  'SHOW_DESKTOP_PLUS_ENABLE_HOTKEY="true"' \
  'SHOW_DESKTOP_PLUS_HOTKEY="<Super>d"' \
  'SHOW_DESKTOP_PLUS_SHOW_HIDDEN_COUNT="false"'; do
  grep -Fq "$expected" "$ROOT/config/gnome.conf"
done

grep -Fxq 'unzip' "$ROOT/manifests/packages-system.txt"
show_installer="$ROOT/scripts/gnome/install-show-desktop-plus.sh"
grep -Fq 'https://extensions.gnome.org/review/download/70326.shell-extension.zip' "$show_installer"
grep -Fq 'show-desktop-plus@attentivecoder' "$show_installer"
grep -Fq "curl --fail --location --proto '=https' --tlsv1.2" "$show_installer"
grep -Fq "unzip -p \"\$zip\" metadata.json" "$show_installer"
grep -Fq "glib-compile-schemas \"\$schema_dir\"" "$show_installer"
grep -Fq 'review_id=70326' "$show_installer"

grep -Fq 'install-show-desktop-plus.sh' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'button-position' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'left-click-action' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'show-desktop-hotkey' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'Show Desktop Plus' "$ROOT/diagnostics/gnome-doctor"
grep -Fq 'DING Trash' "$ROOT/diagnostics/gnome-doctor"
grep -Fq 'Show Desktop position' "$ROOT/diagnostics/gnome-doctor"

# The two features must be documented and covered by Fedora host/package CI.
grep -Fq 'Desktop Icons NG' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq 'Show Desktop Plus' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq '74408.shell-extension.zip' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'ding@rastersoft.com' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'show-desktop-plus@attentivecoder' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'test_desktop_ergonomics_contract.sh' "$ROOT/.github/workflows/tests.yml"

echo 'Desktop ergonomics contract: PASS'
