#!/usr/bin/env bash
# Behavioral test: runs the Ubuntu-grade polish module against a fake GNOME
# (gsettings store, gnome-extensions, systemctl, rpm) and checks real outcomes.
# shellcheck disable=SC2317,SC2034,SC2016,SC2030,SC2031,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rc=$?; ((rc == 0)) || cat "$tmp/errors.log" 2>/dev/null >&2; rm -rf "$tmp"' EXIT
fail() { echo "gnome polish behavior: FAIL: $*" >&2; exit 1; }

store="$tmp/gsettings"; mkdir -p "$store" "$tmp/bin" "$tmp/home" "$tmp/repo/scripts/gnome" "$tmp/repo/systemd/user" "$tmp/repo/manifests"
cat > "$tmp/bin/gsettings" <<SH
#!/usr/bin/env bash
op="\$1"; schema="\$2"; key="\$3"
file="$store/\$schema.\$key"
case "\$op" in
  get) if [[ -r "\$file" ]]; then cat "\$file"; elif [[ "\$key" == color-scheme ]]; then echo "'default'"; else echo "'upstream'"; fi ;;
  set)
    value="\$4"
    # Mimic GVariant parsing: a bare word that is not a bool/number is a string.
    if [[ ! "\$value" =~ ^(true|false|[0-9]+|(u?int(32|64)|double)\ [0-9.]+|\'.*\')\$ ]]; then value="'\$value'"; fi
    printf '%s\n' "\$value" > "\$file"; printf '%s %s\n' "\$schema" "\$key" >> "$tmp/set.log" ;;
  *) exit 1 ;;
esac
SH
cat > "$tmp/bin/gnome-extensions" <<SH
#!/usr/bin/env bash
case "\$1" in
  list) echo 'tiling-assistant@leleat-on-github' ;;
  info) [[ -e "$tmp/enabled" ]] && echo 'State: ENABLED' || echo 'State: INACTIVE' ;;
  enable) touch "$tmp/enabled" ;;
esac
SH
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\n[[ "${!#}" == adw-gtk3-theme ]]\n' > "$tmp/bin/rpm"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/sudo.log"\n' "$tmp" > "$tmp/bin/sudo"
chmod +x "$tmp/bin/"*

# Isolated repository copy: the real installer would download from GitHub.
cp "$ROOT/scripts/gnome/gtk3-theme-follow.sh" "$tmp/repo/scripts/gnome/"
cp "$ROOT/systemd/user/fedora-gnome-gtk3-theme-follow.service" "$tmp/repo/systemd/user/"
cp "$ROOT/manifests/packages-gnome-polish.txt" "$tmp/repo/manifests/"
printf '#!/usr/bin/env bash\necho "$@" > "%s/tiling-install.args"\n' "$tmp" > "$tmp/repo/scripts/gnome/install-tiling-assistant.sh"

run_module() {
  (
    PATH="$tmp/bin:$PATH"; HOME="$tmp/home"; REPO_ROOT="$tmp/repo"
    source "$ROOT/lib/constants.sh"
    is_true() { [[ "${1,,}" == true ]]; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    log_info() { :; }; log_warn() { :; }; log_error() { printf '%s\n' "$*" >> "$tmp/errors.log"; }
    source "$ROOT/lib/mutations.sh"
    # shellcheck disable=SC1091
    source "$ROOT/config/gnome-extensions.lock"; source "$ROOT/config/gnome.conf"; source "$ROOT/config/gnome-polish.conf"
    for override in "${@:2}"; do eval "$override"; done
    source "$ROOT/modules/gnome/24c_ubuntu_polish.sh"
    "gnome_polish_$1"
  )
}

# 1. Dry-run never mutates anything.
run_module precheck
run_module apply DRY_RUN=true
[[ ! -e "$tmp/set.log" && ! -e "$tmp/sudo.log" && ! -e "$tmp/tiling-install.args" ]] || fail 'dry-run mutated the system'

# 2. Invalid configuration is refused before any change.
rc=0; run_module precheck POLISH_ACCENT_COLOR=rainbow || rc=$?
[[ "$rc" -eq 60 ]] || fail "invalid accent accepted (rc=$rc)"
rc=0; run_module precheck POLISH_DOCK_ICON_SIZE=500 || rc=$?
[[ "$rc" -eq 60 ]] || fail "absurd icon size accepted (rc=$rc)"

# 3. Real APPLY converges and POSTCHECK proves it.
run_module apply DRY_RUN=false
grep -Fq 'adw-gtk3-theme' "$tmp/sudo.log" || fail 'adw-gtk3-theme not installed'
grep -Fq 'tiling-assistant@leleat-on-github' "$tmp/tiling-install.args" || fail 'Tiling Assistant installer not called'
[[ "$(cat "$store/org.gnome.shell.extensions.dash-to-dock.dock-position")" == "'LEFT'" ]] || fail 'dock not moved left'
[[ "$(cat "$store/org.gnome.shell.extensions.dash-to-dock.disable-overview-on-startup")" == true ]] || fail 'session still opens on overview'
[[ "$(cat "$store/org.gnome.desktop.interface.accent-color")" == "'orange'" ]] || fail 'accent color'
[[ "$(cat "$store/org.gnome.desktop.interface.color-scheme")" == "'prefer-dark'" ]] || fail 'OLED dark default not applied'
[[ "$(cat "$store/org.gnome.desktop.interface.gtk-theme")" == "'adw-gtk3-dark'" ]] || fail 'GTK3 theme not aligned with dark style'
[[ "$(cat "$store/org.gnome.shell.extensions.dash-to-dock.intellihide")" == true ]] || fail 'OLED-safe dock intellihide missing'
[[ "$(cat "$store/org.gnome.desktop.session.idle-delay")" == 'uint32 300' ]] || fail 'OLED idle blank missing'
[[ -x "$tmp/home/.local/libexec/fedora-gnome-gtk3-theme-follow" ]] || fail 'light/dark watcher not installed'
[[ -e "$tmp/enabled" ]] || fail 'Tiling Assistant not enabled'
run_module postcheck DRY_RUN=false || fail 'postcheck rejected a converged desktop'

# 4. The user switches to light in GNOME Settings: GTK3 follows, it is NOT drift,
#    and a later APPLY does not force dark mode back.
echo "'default'" > "$store/org.gnome.desktop.interface.color-scheme"
PATH="$tmp/bin:$PATH" bash "$tmp/home/.local/libexec/fedora-gnome-gtk3-theme-follow" once
[[ "$(cat "$store/org.gnome.desktop.interface.gtk-theme")" == "'adw-gtk3'" ]] || fail 'light style not mirrored'
run_module postcheck DRY_RUN=false || fail 'postcheck treated the user light/dark choice as drift'
run_module apply DRY_RUN=false
[[ "$(cat "$store/org.gnome.desktop.interface.color-scheme")" == "'default'" ]] || fail 'APPLY overwrote the user light/dark choice'

# 5. Drift is detected.
echo "'BOTTOM'" > "$store/org.gnome.shell.extensions.dash-to-dock.dock-position"
rc=0; run_module postcheck DRY_RUN=false || rc=$?
[[ "$rc" -eq 40 ]] || fail "dock drift not detected (rc=$rc)"
grep -Fq 'dock-position' "$tmp/errors.log" || fail 'drift message does not name the key'

echo 'gnome polish behavior: PASS'
