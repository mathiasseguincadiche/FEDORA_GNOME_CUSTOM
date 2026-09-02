#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

UPDATE_STATE_FILE="$STATE_ROOT/last-system-update.status"
UPDATE_REBOOT_REQUIRED="unknown"

usage() {
  cat <<'EOF'
Usage: update-system.sh [--check|--apply|--dnf-only|--flatpak-only|--firmware-check]

  --check           Read-only overview: Fedora, Flatpak and firmware updates
  --apply           Protected full update: full Restic backup, DNF, Flatpak, firmware check, doctor
  --dnf-only        Protected Fedora package update with mandatory full Restic backup
  --flatpak-only    Update Flatpak applications only
  --firmware-check  Show firmware updates only; never flashes firmware
EOF
}

require_fedora() {
  if [[ ! -r /etc/os-release ]]; then
    ui_error '/etc/os-release unavailable'
    exit "$EXIT_PRECHECK_FAILED"
  fi
  if ! grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release; then
    ui_error 'This updater is Fedora-only'
    exit "$EXIT_PRECHECK_FAILED"
  fi
}

require_baremetal_update() {
  if ! runtime_is_baremetal; then
    ui_error "Mutating updates are bare-metal only (runtime=$RUNTIME_ENVIRONMENT)"
    exit "$EXIT_SECURITY_BLOCK"
  fi
}

check_dnf() {
  local rc=0
  if ! command_exists dnf; then
    ui_check KO 'Fedora updates' 'dnf unavailable'
    return "$EXIT_PRECHECK_FAILED"
  fi
  printf '\n--- Fedora packages ---\n'
  if dnf check-update; then
    ui_check PASS 'Fedora updates' 'no pending package update reported'
    return 0
  fi
  rc=$?
  if ((rc == 100)); then
    ui_check WARN 'Fedora updates' 'updates are available'
    return 0
  fi
  ui_check KO 'Fedora updates' "dnf check-update rc=$rc"
  return "$rc"
}

check_flatpak() {
  local pending=''
  printf '\n--- Flatpak ---\n'
  if ! command_exists flatpak; then
    ui_check EXPECTED 'Flatpak updates' 'flatpak unavailable'
    return 0
  fi
  pending="$(flatpak remote-ls --updates --columns=application 2>/dev/null | sed '/^[[:space:]]*$/d' || true)"
  if [[ -n "$pending" ]]; then
    printf '%s\n' "$pending"
    ui_check WARN 'Flatpak updates' 'updates are available'
  else
    ui_check PASS 'Flatpak updates' 'no pending application update reported'
  fi
}

check_firmware() {
  printf '\n--- Firmware ---\n'
  if ! command_exists fwupdmgr; then
    ui_check EXPECTED 'Firmware updates' 'fwupdmgr unavailable'
    return 0
  fi
  # Deliberately informational: firmware flashing remains a separate explicit operator action.
  if fwupdmgr get-updates --no-metadata-check 2>/dev/null; then
    ui_check PASS 'Firmware query' 'completed — no firmware was flashed'
  else
    ui_check WARN 'Firmware query' 'no update or provider returned non-zero; no firmware was flashed'
  fi
}

mandatory_preupdate_backup() {
  ui_banner 'FEDORA WORKSTATION UPDATE' 'MANDATORY PRE-UPDATE RESTIC BACKUP'
  "$REPO_ROOT/scripts/backup/backup-now.sh"
  ui_check PASS 'Pre-update backup' 'full snapshot + integrity check completed'
}

apply_dnf() {
  if ! command_exists sudo || ! command_exists dnf; then
    ui_error 'sudo/dnf unavailable'
    exit "$EXIT_PRECHECK_FAILED"
  fi
  ui_banner 'FEDORA WORKSTATION UPDATE' 'FEDORA PACKAGES + GOLDEN KERNEL POLICY'
  sudo dnf upgrade --refresh -y
  ui_check PASS 'Fedora packages' 'upgrade transaction completed'
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

detect_reboot_required() {
  local current=''
  local newest=''
  UPDATE_REBOOT_REQUIRED="false"

  if command_exists needs-restarting && ! needs-restarting -r >/dev/null 2>&1; then
    UPDATE_REBOOT_REQUIRED="true"
    return 0
  fi

  if command_exists rpm; then
    current="$(uname -r)"
    newest="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' kernel-core 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$newest" && "$current" != "$newest" && "$current" != "$newest".* ]]; then
      UPDATE_REBOOT_REQUIRED="true"
    fi
  fi
}

write_update_state() {
  local mode="$1"
  local doctor_rc="$2"
  local tmp=''
  mkdir -p "$STATE_ROOT"
  tmp="$(mktemp "$STATE_ROOT/.last-system-update.XXXXXX")"
  {
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'commit=%s\n' "$(repo_commit)"
    printf 'mode=%s\n' "$mode"
    printf 'doctor_rc=%s\n' "$doctor_rc"
    printf 'reboot_required=%s\n' "$UPDATE_REBOOT_REQUIRED"
    printf 'kernel_running=%s\n' "$(uname -r)"
  } > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$UPDATE_STATE_FILE"
}

post_update_health() {
  local mode="$1"
  local doctor_rc=0
  ui_banner 'FEDORA WORKSTATION UPDATE' 'POST-UPDATE HEALTH'

  if "$REPO_ROOT/diagnostic.sh"; then
    doctor_rc=0
    ui_check PASS 'Post-update diagnostic' 'global doctor completed'
  else
    doctor_rc=$?
    ui_check WARN 'Post-update diagnostic' "doctor rc=$doctor_rc"
  fi

  detect_reboot_required
  if [[ "$UPDATE_REBOOT_REQUIRED" == true ]]; then
    ui_check WARN 'Reboot' 'required/recommended before final post-update certification'
  else
    ui_check PASS 'Reboot' 'no reboot requirement detected'
  fi

  write_update_state "$mode" "$doctor_rc"

  if ((doctor_rc != 0)); then
    if [[ "$UPDATE_REBOOT_REQUIRED" == true ]]; then
      ui_summary 'UPDATE APPLIED — POSTCHECK PENDING' 'REBOOT, THEN RUN ./diagnostic.sh; DO NOT TREAT THE NEW STACK AS CERTIFIED YET' "$UPDATE_STATE_FILE" "$LOG_DIR"
    else
      ui_summary 'UPDATE APPLIED — POSTCHECK FAILED' 'INSPECT THE DIAGNOSTIC BEFORE CONTINUING' "$UPDATE_STATE_FILE" "$LOG_DIR"
    fi
    return "$EXIT_POSTCHECK_FAILED"
  fi

  if [[ "$UPDATE_REBOOT_REQUIRED" == true ]]; then
    ui_summary 'UPDATE APPLIED' 'REBOOT REQUIRED/RECOMMENDED, THEN RE-RUN DIAGNOSTIC FOR RUNTIME CERTIFICATION' "$UPDATE_STATE_FILE" "$LOG_DIR"
  else
    ui_summary 'UPDATE COMPLETED' 'POST-UPDATE HEALTH PASS' "$UPDATE_STATE_FILE" "$LOG_DIR"
  fi
  return 0
}

mode="${1:---check}"
case "$mode" in
  -h|--help)
    usage
    exit 0
    ;;
esac

require_fedora

case "$mode" in
  --check)
    ui_banner 'FEDORA WORKSTATION UPDATE' 'READ-ONLY UPDATE OVERVIEW'
    check_dnf
    check_flatpak
    check_firmware
    ;;
  --apply)
    require_baremetal_update
    mandatory_preupdate_backup
    apply_dnf
    apply_flatpak
    check_firmware
    post_update_health full
    ;;
  --dnf-only)
    require_baremetal_update
    mandatory_preupdate_backup
    apply_dnf
    post_update_health dnf-only
    ;;
  --flatpak-only)
    require_baremetal_update
    apply_flatpak
    ;;
  --firmware-check)
    check_firmware
    ;;
  *)
    usage >&2
    exit "$EXIT_USAGE"
    ;;
esac
