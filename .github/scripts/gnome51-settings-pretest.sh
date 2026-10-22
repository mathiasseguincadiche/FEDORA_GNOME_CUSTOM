#!/usr/bin/env bash
# Real schemas/settings in a disposable Fedora 45 CI container. No Shell or hardware PASS.
set -Eeuo pipefail
[[ "${CI:-}" == true && -f /.dockerenv ]] || exit 50
grep -Eq '^VERSION_ID="?45"?$' /etc/os-release || exit 50
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/scripts/development/fedora-profile.py" candidate "$ROOT" 45
if [[ "${1:-}" != --user ]]; then
  [[ "$EUID" == 0 ]] || exit 50
  useradd -m gnome51settings
  exec runuser -u gnome51settings -- env HOME=/home/gnome51settings \
    XDG_DATA_HOME=/home/gnome51settings/.local/share CI=true \
    dbus-run-session -- bash "$0" --user
fi
[[ "$EUID" != 0 && "$(id -un)" == gnome51settings ]] || exit 50
# shellcheck source=config/gnome-extensions.lock
source "$ROOT/config/gnome-extensions.lock"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for prefix in DING SHOW_DESKTOP_PLUS RESOURCE_MONITOR TILING_ASSISTANT; do
  url="${prefix}_SOURCE_URL"; digest="${prefix}_SHA256"; uuid="${prefix}_UUID"
  zip="$tmp/$prefix.zip"
  curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 "${!url}" -o "$zip"
  printf '%s  %s\n' "${!digest}" "$zip" | sha256sum --check --status
  dir="$XDG_DATA_HOME/gnome-shell/extensions/${!uuid}"
  mkdir -p "$dir"
  unzip -q "$zip" -d "$dir"
  python3 "$ROOT/scripts/gnome/validate-extension-metadata.py" "$dir/metadata.json" "${!uuid}" 51
  glib-compile-schemas "$dir/schemas"
  if [[ "$prefix" == DING ]]; then
    python3 "$ROOT/scripts/gnome/ding-shutdown-fix.py" apply "$zip" "$dir"
  fi
done
run_mutating() { shift; "$@"; }
is_true() { [[ "$1" == true ]]; }
EXIT_APPLY_FAILED=30
EXIT_POSTCHECK_FAILED=40
# These are the same production settings functions exercised in the QEMU session lab.
# shellcheck source=modules/gnome/24_gnome_extensions.sh
source "$ROOT/modules/gnome/24_gnome_extensions.sh"
# shellcheck source=modules/gnome/24b_resource_monitor.sh
source "$ROOT/modules/gnome/24b_resource_monitor.sh"
gnome_ding_settings_apply
gnome_show_desktop_button_settings_apply
gnome_show_desktop_button_settings_check
resource_monitor_vitals_apply
resource_monitor_vitals_check
test "$(xdg-user-dir DESKTOP)" = "$HOME/Bureau"
schema_dir="$(gnome_ding_schema_dir)"
test "$(gsettings --schemadir "$schema_dir" get "$DING_SCHEMA" show-trash)" = true
test "$(gsettings --schemadir "$schema_dir" get "$DING_SCHEMA" show-home)" = false
test "$(gsettings --schemadir "$schema_dir" get "$DING_SCHEMA" show-volumes)" = false
test "$(gsettings --schemadir "$schema_dir" get "$DING_SCHEMA" show-network-volumes)" = false
echo 'GNOME 51 reviewed schemas, desktop settings and Vitals: PASS; session activation and hardware remain separate.'
