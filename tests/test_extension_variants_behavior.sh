#!/usr/bin/env bash
# Behavioral test: the Fedora 45 / GNOME 51 replacements (Show Desktop Button, Vitals, Gtk4 DING)
# are configured and verified through a fake gsettings store; the Fedora 44 identities keep
# selecting the original code paths.
# shellcheck disable=SC2317,SC2034,SC2016,SC2030,SC2031,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "extension variants behavior: FAIL: $*" >&2; exit 1; }

store="$tmp/gsettings"; mkdir -p "$store" "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/gsettings" <<SH
#!/usr/bin/env bash
[[ "\$1" == --schemadir ]] && shift 2
op="\$1"; schema="\$2"; key="\$3"
file="$store/\$schema.\$key"
case "\$op" in
  get) [[ -r "\$file" ]] && cat "\$file" || echo unset ;;
  set) printf '%s\n' "\$4" > "\$file" ;;
  *) exit 1 ;;
esac
SH
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/xdg-user-dirs-update"
chmod +x "$tmp/bin/"*

run() {
  (
    PATH="$tmp/bin:$PATH"; HOME="$tmp/home"; XDG_DATA_HOME="$tmp/data"; REPO_ROOT="$ROOT"
    source "$ROOT/lib/constants.sh"
    is_true() { [[ "${1,,}" == true ]]; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    run_mutating() { shift; "$@"; }
    log_warn() { :; }; log_error() { :; }
    source "$ROOT/config/gnome.conf"
    source "$ROOT/modules/gnome/24_gnome_extensions.sh"
    source "$ROOT/modules/gnome/24b_resource_monitor.sh"
    "$@"
  )
}
use_lock() { # use_lock FILE -> exports its variables for the next run
  set -a; source "$1"; set +a
}

# --- Fedora 45 reviewed identities -------------------------------------------------------
(
  use_lock "$ROOT/profiles/fedora45/gnome-extensions.lock"
  run gnome_show_desktop_is_button || fail 'Show Desktop Button identity not detected'
  run resource_monitor_is_vitals || fail 'Vitals identity not detected'
  [[ "$(run gnome_show_desktop_label)" == 'Show Desktop Button' ]] || fail 'button label'
  [[ "$(run resource_monitor_label)" == 'Vitals' ]] || fail 'vitals label'

  run gnome_show_desktop_plus_settings_apply || fail 'button settings apply'
  [[ "$(<"$store/org.gnome.shell.extensions.show-desktop-button.indicator-position")" == "'LEFT_END'" ]] || fail 'button position'
  [[ "$(<"$store/org.gnome.shell.extensions.show-desktop-button.show-desktop-shortcut")" == "['<Super>d']" ]] || fail 'button shortcut'
  run gnome_show_desktop_button_settings_check || fail 'button check on applied settings'
  printf "'RIGHT'\n" > "$store/org.gnome.shell.extensions.show-desktop-button.indicator-position"
  if run gnome_show_desktop_button_settings_check; then fail 'button check accepted a moved indicator'; fi

  run resource_monitor_vitals_apply || fail 'vitals apply'
  [[ "$(<"$store/org.gnome.shell.extensions.vitals.update-time")" == 2 ]] || fail 'vitals refresh'
  [[ "$(<"$store/org.gnome.shell.extensions.vitals.position-in-panel")" == 2 ]] || fail 'vitals position'
  expected="['_processor_usage_', '_memory_usage_', '__network-rx_max__', '__network-tx_max__']"
  [[ "$(<"$store/org.gnome.shell.extensions.vitals.hot-sensors")" == "$expected" ]] || fail 'vitals sensors'
  run resource_monitor_vitals_check || fail 'vitals check on applied settings'
  printf '5\n' > "$store/org.gnome.shell.extensions.vitals.update-time"
  if run resource_monitor_vitals_check; then fail 'vitals check accepted a changed refresh'; fi

  # Gtk4 DING keeps the keys the DING settings code writes.
  run gnome_ding_settings_apply || fail 'gtk4 ding settings'
  [[ "$(<"$store/org.gnome.shell.extensions.gtk4-ding.show-trash")" == true ]] || fail 'ding trash'
  [[ "$(<"$store/org.gnome.shell.extensions.gtk4-ding.show-network-volumes")" == false ]] || fail 'ding network volumes'
)

# --- Fedora 44 identities keep the original paths -------------------------------------------
(
  use_lock "$ROOT/config/gnome-extensions.lock"
  if run gnome_show_desktop_is_button; then fail 'Fedora 44 lock selected the Button variant'; fi
  if run resource_monitor_is_vitals; then fail 'Fedora 44 lock selected the Vitals variant'; fi
  [[ "$(run gnome_show_desktop_label)" == 'Show Desktop Plus' ]] || fail 'plus label'
  [[ "$(run resource_monitor_label)" == 'Resource Monitor' ]] || fail 'resource monitor label'
)

echo 'extension variants behavior: PASS'
