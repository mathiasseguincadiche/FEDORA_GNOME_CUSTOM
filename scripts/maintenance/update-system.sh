#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

UPDATE_STATE_FILE="$STATE_ROOT/last-system-update.status"
UPDATE_REBOOT_REQUIRED="unknown"

usage() {
  cat <<'EOF'
Usage: update-system.sh [ACTION]

  --check           Read-only overview: Fedora, Flatpak, firmware and offline state
  --apply           Backup + prepare a full Fedora DNF5 offline transaction
  --dnf-only        Backup + prepare a Fedora-only DNF5 offline transaction
  --offline-reboot  Reboot into the prepared DNF5 offline transaction
  --finalize        After normal boot: validate DNF, then Flatpak (full mode), firmware check and doctor
  --offline-status  Show project marker and DNF5 offline status
  --offline-log     Show the latest DNF5 offline transaction log
  --flatpak-only    Update Flatpak applications only
  --firmware-check  Show firmware updates only; never flashes firmware
EOF
}

require_fedora() {
  [[ -r /etc/os-release ]] || { ui_error '/etc/os-release unavailable'; exit "$EXIT_PRECHECK_FAILED"; }
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || { ui_error 'This updater is Fedora-only'; exit "$EXIT_PRECHECK_FAILED"; }
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || { ui_error 'Golden updater expects Fedora 44'; exit "$EXIT_PRECHECK_FAILED"; }
}

require_baremetal_update() {
  runtime_is_baremetal || { ui_error "Mutating updates are bare-metal only (runtime=$RUNTIME_ENVIRONMENT)"; exit "$EXIT_SECURITY_BLOCK"; }
}

require_dnf5() {
  command_exists dnf5 || { ui_error 'dnf5 is required by the Golden offline-update policy'; exit "$EXIT_PRECHECK_FAILED"; }
}

update_state_value() {
  evidence_marker_value "$UPDATE_STATE_FILE" "$1" 2>/dev/null || true
}

write_update_state() {
  local phase="$1" mode="$2" doctor_rc="${3:-pending}"
  {
    printf 'schema=1\n'
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'commit=%s\n' "$(repo_commit)"
    printf 'effective_config_sha256=%s\n' "$(effective_config_sha256)"
    printf 'phase=%s\n' "$phase"
    printf 'mode=%s\n' "$mode"
    printf 'doctor_rc=%s\n' "$doctor_rc"
    printf 'reboot_required=%s\n' "$UPDATE_REBOOT_REQUIRED"
    printf 'kernel_running=%s\n' "$(uname -r)"
  } | evidence_atomic_write "$UPDATE_STATE_FILE" 0600
}

require_current_update_state() {
  local phase mode
  [[ -s "$UPDATE_STATE_FILE" ]] || { ui_error 'No project-owned offline update state exists'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$(update_state_value commit)" == "$(repo_commit)" ]] || { ui_error 'Update state belongs to another Git commit'; return "$EXIT_SECURITY_BLOCK"; }
  [[ "$(update_state_value effective_config_sha256)" == "$(effective_config_sha256)" ]] || { ui_error 'Update state belongs to another effective configuration'; return "$EXIT_SECURITY_BLOCK"; }
  phase="$(update_state_value phase)"; mode="$(update_state_value mode)"
  [[ "$phase" == prepared || "$phase" == reboot-requested ]] || { ui_error "Offline update state is not pending: phase=${phase:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$mode" == full || "$mode" == dnf-only ]] || { ui_error "Invalid offline update mode: ${mode:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
}

check_dnf() {
  local rc=0
  require_dnf5
  printf '\n--- Fedora packages ---\n'
  if dnf5 check-upgrade; then
    ui_check PASS 'Fedora updates' 'no pending package upgrade reported'
  else
    rc=$?
    if ((rc == 100)); then
      ui_check WARN 'Fedora updates' 'updates are available'
    else
      ui_check KO 'Fedora updates' "dnf5 check-upgrade rc=$rc"
      return "$rc"
    fi
  fi
}

check_flatpak() {
  local pending=''
  printf '\n--- Flatpak ---\n'
  if ! command_exists flatpak; then ui_check EXPECTED 'Flatpak updates' 'flatpak unavailable'; return 0; fi
  pending="$(flatpak remote-ls --updates --columns=application 2>/dev/null | sed '/^[[:space:]]*$/d' || true)"
  if [[ -n "$pending" ]]; then printf '%s\n' "$pending"; ui_check WARN 'Flatpak updates' 'updates are available'; else ui_check PASS 'Flatpak updates' 'no pending application update reported'; fi
}

check_firmware() {
  printf '\n--- Firmware ---\n'
  if ! command_exists fwupdmgr; then ui_check EXPECTED 'Firmware updates' 'fwupdmgr unavailable'; return 0; fi
  if fwupdmgr get-updates --no-metadata-check 2>/dev/null; then
    ui_check PASS 'Firmware query' 'completed — no firmware was flashed'
  else
    ui_check WARN 'Firmware query' 'no update or provider returned non-zero; no firmware was flashed'
  fi
}

show_offline_status() {
  printf '\n--- Project update state ---\n'
  if [[ -s "$UPDATE_STATE_FILE" ]]; then cat "$UPDATE_STATE_FILE"; else printf 'none\n'; fi
  printf '\n--- DNF5 offline state ---\n'
  if command_exists dnf5; then sudo -n dnf5 offline status 2>&1 || dnf5 offline status 2>&1 || true; else printf 'dnf5 unavailable\n'; fi
}

mandatory_preupdate_backup() {
  ui_banner 'FEDORA WORKSTATION UPDATE' 'MANDATORY PRE-UPDATE RESTIC BACKUP'
  "$REPO_ROOT/scripts/backup/backup-now.sh"
  ui_check PASS 'Pre-update backup' 'full snapshot + integrity check completed'
}

prepare_dnf_offline() {
  local mode="$1"
  require_dnf5
  if [[ -s "$UPDATE_STATE_FILE" && "$(update_state_value phase)" =~ ^(prepared|reboot-requested)$ ]]; then
    ui_error 'A project-owned offline update is already pending; finalize it before preparing another one'
    exit "$EXIT_SECURITY_BLOCK"
  fi
  ui_banner 'FEDORA WORKSTATION UPDATE' 'PREPARE DNF5 OFFLINE TRANSACTION'
  sudo dnf5 --refresh upgrade --offline -y
  sudo dnf5 offline status
  UPDATE_REBOOT_REQUIRED=true
  write_update_state prepared "$mode" pending
  ui_summary 'OFFLINE UPDATE PREPARED' 'NO RPM WAS REPLACED IN THE RUNNING SESSION — NEXT: ./control.sh update reboot' "$UPDATE_STATE_FILE" "$LOG_DIR"
}

request_offline_reboot() {
  require_dnf5
  require_current_update_state || exit $?
  local mode
  mode="$(update_state_value mode)"
  sudo dnf5 offline status >/dev/null
  UPDATE_REBOOT_REQUIRED=true
  write_update_state reboot-requested "$mode" pending
  ui_check WARN 'DNF5 offline reboot' 'system will reboot into the minimal offline transaction now'
  sudo dnf5 offline reboot
}

apply_flatpak() {
  if command_exists flatpak; then
    ui_banner 'FEDORA WORKSTATION UPDATE' 'FLATPAK APPLICATIONS'
    flatpak update -y
    ui_check PASS 'Flatpak applications' 'update transaction completed'
  else
    ui_check EXPECTED 'Flatpak applications' 'flatpak unavailable'
  fi
}

capture_offline_log() {
  local report="$REPORT_ROOT/$RUN_ID-dnf5-offline-last.log"
  sudo dnf5 offline log --number=-1 > "$report" 2>&1 || {
    ui_error "Unable to read latest DNF5 offline log: $report"
    return "$EXIT_POSTCHECK_FAILED"
  }
  ui_check PASS 'DNF5 offline log' "$report"
}

finalize_offline_update() {
  require_dnf5
  require_current_update_state || exit $?
  local mode doctor_rc=0
  mode="$(update_state_value mode)"
  ui_banner 'FEDORA WORKSTATION UPDATE' 'POST-OFFLINE VALIDATION'

  capture_offline_log || exit $?
  sudo dnf5 check || { ui_error 'DNF5 packagedb/dependency validation failed after offline transaction'; write_update_state failed "$mode" 1; exit "$EXIT_POSTCHECK_FAILED"; }
  ui_check PASS 'DNF5 packagedb' 'dependency/database check PASS'

  if [[ "$mode" == full ]]; then apply_flatpak; fi
  check_firmware

  if "$REPO_ROOT/diagnostic.sh"; then
    doctor_rc=0
    ui_check PASS 'Post-update diagnostic' 'global doctor completed'
  else
    doctor_rc=$?
    ui_check KO 'Post-update diagnostic' "doctor rc=$doctor_rc"
  fi

  UPDATE_REBOOT_REQUIRED=false
  if ((doctor_rc == 0)); then
    write_update_state completed "$mode" 0
    ui_summary 'UPDATE COMPLETED' 'OFFLINE RPM TRANSACTION + POSTCHECK PASS; RECERTIFY IF THE SOFTWARE MATRIX CHANGED' "$UPDATE_STATE_FILE" "$LOG_DIR"
  else
    write_update_state failed "$mode" "$doctor_rc"
    ui_summary 'UPDATE POSTCHECK FAILED' 'INSPECT DNF5 OFFLINE LOG AND DIAGNOSTICS BEFORE CONTINUING' "$UPDATE_STATE_FILE" "$LOG_DIR"
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

mode="${1:---check}"
case "$mode" in
  -h|--help) usage; exit 0 ;;
esac

require_fedora

case "$mode" in
  --check)
    ui_banner 'FEDORA WORKSTATION UPDATE' 'READ-ONLY UPDATE OVERVIEW'
    check_dnf; check_flatpak; check_firmware; show_offline_status
    ;;
  --apply)
    require_baremetal_update; mandatory_preupdate_backup; prepare_dnf_offline full
    ;;
  --dnf-only)
    require_baremetal_update; mandatory_preupdate_backup; prepare_dnf_offline dnf-only
    ;;
  --offline-reboot)
    require_baremetal_update; request_offline_reboot
    ;;
  --finalize)
    require_baremetal_update; finalize_offline_update
    ;;
  --offline-status)
    show_offline_status
    ;;
  --offline-log)
    require_dnf5; sudo dnf5 offline log --number=-1
    ;;
  --flatpak-only)
    require_baremetal_update; apply_flatpak
    ;;
  --firmware-check)
    check_firmware
    ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac
