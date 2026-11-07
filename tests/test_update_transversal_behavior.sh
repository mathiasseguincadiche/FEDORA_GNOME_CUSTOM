#!/usr/bin/env bash
# Read-only update diagnostics, trusted Steam RPM provenance, and the complete
# interactive DNF5 lifecycle. No host package, firmware or boot state is changed.
# shellcheck disable=SC2317,SC2329,SC2034,SC1090
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "transversal update behavior: FAIL: $*" >&2; exit 1; }
STATE_ROOT="$tmp/state"
REPORT_ROOT="$tmp/reports"
LOG_DIR="$tmp/logs"
MAIN_LOG="$LOG_DIR/main.log"
XDG_RUNTIME_DIR="$tmp/runtime"
export XDG_RUNTIME_DIR
mkdir -p "$STATE_ROOT" "$REPORT_ROOT" "$LOG_DIR" "$XDG_RUNTIME_DIR"

# Load real production update functions without executing the CLI dispatcher.
source <(sed -e 's/^engine_bootstrap$/engine_load_libraries; config_load/' \
  -e '/^mode="\${1:---check}"$/,$d' \
  -e "s|^REPO_ROOT=.*|REPO_ROOT='$ROOT'|" \
  "$ROOT/scripts/maintenance/update-system.sh")

flatpak() {
  [[ "$*" == 'remote-ls --updates --columns=application' ]] || return 99
  case "${T_FLATPAK_CASE:-}" in
    error) echo 'repository unavailable' >&2; return 44 ;;
    pending) echo 'org.example.Pending' ;;
    *) return 0 ;;
  esac
}

T_FLATPAK_CASE=error
rc=0
check_flatpak > "$tmp/flatpak-error" || rc=$?
[[ "$rc" -eq 44 ]] || fail "Flatpak lookup error was hidden (rc=$rc)"
grep -Fq '[KO' "$tmp/flatpak-error" || fail 'Flatpak lookup error lacked a KO verdict'
if grep -Fq 'no pending' "$tmp/flatpak-error"; then fail 'failed Flatpak lookup falsely claimed no updates'; fi
T_FLATPAK_CASE=pending
check_flatpak > "$tmp/flatpak-pending" || fail 'valid pending Flatpak lookup failed'
grep -Fq 'org.example.Pending' "$tmp/flatpak-pending" || fail 'pending Flatpak was hidden'
T_FLATPAK_CASE=clean
check_flatpak > "$tmp/flatpak-clean" || fail 'valid clean Flatpak lookup failed'
grep -Fq 'aucune mise à jour disponible' "$tmp/flatpak-clean" || fail 'clean Flatpak state was not reported'

ENABLE_KERNEL_VANILLA_STABLE=true
kernel_lifecycle_status() { return 64; }
rc=0; check_kernel > "$tmp/kernel-error" || rc=$?
[[ "$rc" -eq 64 ]] || fail 'failed kernel inventory was hidden'
grep -Fq 'noyau non vérifié' "$tmp/kernel-error" || fail 'kernel inventory was wrongly treated as healthy'

fwupdmgr() { printf 'source firmware temporairement indisponible\n' >&2; return 9; }
rc=0; check_firmware > "$tmp/firmware-uncertain" || rc=$?
[[ "$rc" -eq "$EXIT_PRECHECK_FAILED" ]] || fail "firmware uncertainty was accepted as a successful verification (rc=$rc)"
grep -Fq '[WARN' "$tmp/firmware-uncertain" || fail 'firmware uncertainty lacked a warning'
grep -Fq 'retour fwupdmgr=9' "$tmp/firmware-uncertain" || fail 'firmware error code was hidden'
grep -Fq 'source firmware temporairement indisponible' "$tmp/firmware-uncertain" || fail 'firmware diagnostic was hidden'
if grep -Fq 'aucune mise à jour disponible' "$tmp/firmware-uncertain"; then fail 'uncertain firmware lookup was mistaken for no updates'; fi

T_STEAM_INSTALLED=false
T_STEAM_OWNER='fedora-workstation-repositories'
T_STEAM_REPO=true
T_STEAM_SOURCE=true
printf '[rpmfusion-nonfree-steam]\n' > "$tmp/fedora-owned-steam.repo"
rpm() {
  case "$1" in
    -q) [[ "$2" == steam && "$T_STEAM_INSTALLED" == true ]] ;;
    -qf) printf '%s\n' "$T_STEAM_OWNER" ;;
    *) return 99 ;;
  esac
}
gaming_steam_repository_file() { [[ "$T_STEAM_SOURCE" == true ]] && printf '%s\n' "$tmp/fedora-owned-steam.repo"; }
dnf5() {
  [[ "$*" == 'repolist --all' ]] || return 99
  [[ "$T_STEAM_REPO" == true ]] || return 80
  printf 'repo id                 repo name\nrpmfusion-nonfree-steam Steam (RPM Fusion)\n'
}

[[ -z "$(update_steam_repository_flag)" ]] || fail 'Steam repository enabled when RPM not installed'
T_STEAM_INSTALLED=true
[[ "$(update_steam_repository_flag)" == '--enablerepo=rpmfusion-nonfree-steam' ]] || fail 'installed Steam repository was not enabled'
check_update_scope > "$tmp/scope" || fail 'valid scope incorrectly refused Steam'
grep -Fq 'Proton / jeux Steam' "$tmp/scope" || fail 'Steam-managed Proton boundary omitted'
grep -Fq 'AppImage autonomes' "$tmp/scope" || fail 'AppImage update boundary omitted'
grep -Fq 'Firmware périphériques' "$tmp/scope" || fail 'firmware update boundary omitted'

T_STEAM_SOURCE=false
rc=0; update_steam_repository_flag > "$tmp/steam-source-missing" 2>&1 || rc=$?
[[ "$rc" -ne 0 ]] || fail 'missing Steam repository was accepted'
T_STEAM_SOURCE=true
T_STEAM_OWNER='untrusted-repo'
rc=0; update_steam_repository_flag > "$tmp/steam-owner-wrong" 2>&1 || rc=$?
[[ "$rc" -eq "$EXIT_SECURITY_BLOCK" ]] || fail 'foreign Steam repository ownership was accepted'
T_STEAM_OWNER='fedora-workstation-repositories'
T_STEAM_REPO=false
rc=0; update_steam_repository_flag > "$tmp/steam-unavailable" 2>&1 || rc=$?
[[ "$rc" -ne 0 ]] || fail 'unavailable Steam DNF repository was accepted'
T_STEAM_REPO=true
printf '[unexpected-repository]\n' > "$tmp/fedora-owned-steam.repo"
rc=0; update_steam_repository_flag > "$tmp/steam-wrong-section" 2>&1 || rc=$?
[[ "$rc" -eq "$EXIT_SECURITY_BLOCK" ]] || fail 'Steam repository file without the expected section was accepted'

# A failing domain must not hide the results of the other read-only checks.
check_dnf() { echo dnf >> "$tmp/overview"; }
check_kernel() { echo kernel >> "$tmp/overview"; }
check_flatpak() { echo flatpak >> "$tmp/overview"; return 44; }
check_firmware() { echo firmware >> "$tmp/overview"; }
check_update_scope() { echo scope >> "$tmp/overview"; }
show_offline_status() { echo status >> "$tmp/overview"; }
rc=0; check_updates_overview > "$tmp/overview-output" || rc=$?
[[ "$rc" -eq "$EXIT_PRECHECK_FAILED" ]] || fail 'overview ignored a failed update domain'
[[ "$(paste -sd'|' "$tmp/overview")" == 'dnf|kernel|flatpak|firmware|scope|status' ]] || fail 'overview stopped checking after one domain failed'
grep -Fq 'au moins un domaine non vérifié' "$tmp/overview-output" || fail 'overview hid the incomplete status'

# The menu exercises the real routing, but all operations are mocked. Its
# presence matters: prepare is not completion until reboot and finalize.
source "$ROOT/lib/control_center.sh"
REPO_ROOT="$ROOT"
cc_clear() { :; }
cc_header() { :; }
cc_section() { :; }
cc_option() { :; }
cc_confirm() { [[ "${T_CONFIRM:-true}" == true ]]; }
cc_interactive_exec() { printf 'exec %s\n' "${*:2}" >> "$tmp/menu-calls"; }
cc_interactive_view() { printf 'view %s\n' "${*:2}" >> "$tmp/menu-calls"; }
printf '6\n7\n8\n9\n10\n0\n' | cc_update_menu
for action in '--offline-status' '--offline-log' '--offline-reboot' '--finalize' '--scope'; do
  grep -Fq -- "$action" "$tmp/menu-calls" || fail "interactive update step $action not accessible"
done
: > "$tmp/menu-calls"
printf '8\n0\n' | T_CONFIRM=false cc_update_menu
[[ ! -s "$tmp/menu-calls" ]] || fail 'menu allowed an offline reboot without confirmation'

echo 'transversal update behavior: PASS'
