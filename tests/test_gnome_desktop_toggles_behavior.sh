#!/usr/bin/env bash
# GNOME desktop options run for real: turning display repair off never fails
# APPLY on a host where its watcher was never installed (the orchestrator runs
# modules under errexit), and default applications are found where the
# session finds them, Flatpak exports included.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "gnome desktop toggles behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export HOME="$tmp/home" T_LOG="$tmp/calls" XDG_DATA_HOME="$tmp/home/.local/share"
unset XDG_CONFIG_HOME XDG_STATE_HOME
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
# systemctl --user disable fails for a unit that is not installed, like the real one.
fake systemctl 'printf "systemctl %s\n" "$*" >> "$T_LOG"
[[ "$1 $2" == "--user disable" ]] || exit 0
[[ -e "$HOME/.config/systemd/user/${@: -1}" && -z "${T_DISABLE_FAIL:-}" ]] || { echo "Failed to disable unit: Unit file ${@: -1} does not exist." >&2; exit 1; }'
fake xdg-mime 'printf "xdg-mime %s\n" "$*" >> "$T_LOG"'
fake update-desktop-database ':'
export PATH="$tmp/bin:$PATH"

# Display repair turned off, exactly as the orchestrator runs a phase (errexit, plain command).
display_off() {
  rm -f "$T_LOG"
  bash -c 'set -Eeuo pipefail; source "$1/lib/bootstrap.sh"; REPO_ROOT="$1"; engine_load_libraries
    log_info() { :; }; log_warn() { :; }; source "$1/modules/gnome/25_display_repair.sh"
    DISPLAY_REPAIR_ENABLED=false DRY_RUN=false gnome_display_repair_apply' _ "$ROOT"
}
display_off || fail 'APPLY failed when display repair is off and its watcher was never installed'
[[ ! -e "$T_LOG" ]] || fail "a never-installed watcher was touched: $(paste -sd'|' "$T_LOG")"
mkdir -p "$HOME/.config/systemd/user"; touch "$HOME/.config/systemd/user/fedora-gnome-display-watch.service"
display_off || fail 'installed watcher not disabled'
grep -Fxq 'systemctl --user disable --now fedora-gnome-display-watch.service' "$T_LOG" || fail 'installed watcher not stopped'
rc=0; T_DISABLE_FAIL=1 display_off 2>/dev/null || rc=$?
[[ "$rc" == 30 ]] || fail "a failing disable of an installed watcher was ignored (rc=$rc)"

# Default applications: Flatpak-exported entries count, a missing one is refused.
apps="$XDG_DATA_HOME/flatpak/exports/share/applications"
mkdir -p "$apps"
for desktop in org.gnome.Nautilus.desktop org.gnome.Papers.desktop org.gnome.Loupe.desktop org.gnome.TextEditor.desktop \
  org.gnome.Showtime.desktop org.gnome.FileRoller.desktop brave-browser.desktop; do
  printf '[Desktop Entry]\nType=Application\nName=%s\n' "$desktop" > "$apps/$desktop"
done
rm -f "$T_LOG"
bash "$ROOT/scripts/gnome/configure-default-apps.sh" full > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'Flatpak-exported default applications refused'; }
grep -Fxq 'xdg-mime default org.gnome.Papers.desktop application/pdf' "$T_LOG" \
  && grep -Fxq 'xdg-mime default brave-browser.desktop x-scheme-handler/https' "$T_LOG" || fail "defaults not set: $(paste -sd'|' "$T_LOG")"
rm -f "$T_LOG"
bash "$ROOT/scripts/gnome/configure-default-apps.sh" native > /dev/null 2>&1
grep -q brave-browser "$T_LOG" && fail 'native scope set the browser default'
mv "$apps/org.gnome.Papers.desktop" "$tmp/papers.desktop"
if ! ls /usr/share/applications/org.gnome.Papers.desktop /usr/local/share/applications/org.gnome.Papers.desktop \
     /var/lib/flatpak/exports/share/applications/org.gnome.Papers.desktop >/dev/null 2>&1; then
  rc=0; bash "$ROOT/scripts/gnome/configure-default-apps.sh" native > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == 20 ]] && grep -Fq 'Desktop entry missing: org.gnome.Papers.desktop' "$tmp/out" || fail "missing desktop entry accepted (rc=$rc)"
fi

echo 'gnome desktop toggles behavior: PASS'
