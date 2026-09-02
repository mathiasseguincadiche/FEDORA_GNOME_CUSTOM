#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

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
  [[ -r /etc/os-release ]] || { ui_error '/etc/os-release unavailable'; exit "$EXIT_PRECHECK_FAILED"; }
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || { ui_error 'This updater is Fedora-only'; exit "$EXIT_PRECHECK_FAILED"; }
}

require_baremetal_update() {
  runtime_is_baremetal || {
    ui_error "Mutating updates are bare-metal only (runtime=$RUNTIME_ENVIRONMENT)"
    exit "$EXIT_SECURITY_BLOCK"
  }
}

check_dnf() {
  local rc=0
  if ! command -v dnf >/dev/null 2>&1; then
    ui_check KO 'Fedora updates' 'dnf unavailable'
    return "$EXIT_PRECHECK_FAILED"
  fi
  printf '\n--- Fedora packages ---\n'
  if dnf check-update; then
    ui_check PASS 'Fedora updates' 'no pending package update reported'
  else
    rc=$?
    if ((rc == 100)); then
      ui_check WARN 'Fedora updates' 'updates are available'
    else
      ui_check KO 'Fedora updates' "dnf check-update rc=$rc"
      return "$rc"
    fi
  fi
}

check_flatpak() {
  printf '\n--- Flatpak ---\n'
  if ! command -v flatpak >/dev/null 2>&1; then
    ui_check EXPECTED 'Flatpak updates' 'flatpak unavailable'
    return 0
  fi
  local pending
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
  if ! command -v fwupdmgr >/dev/null 2>&1; then
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
  command -v sudo >/dev/null 2>&1 || { ui_error 'sudo unavailable'; exit "$EXIT_PRECHECK_FAILED"; }
  command -v dnf >/dev/null 2>&1 || { ui_error 'dnf unavailable'; exit "$EXIT_PRECHECK_FAILED"; }
  ui_banner 'FEDORA WORKSTATION UPDATE' 'FEDORA PACKAGES + GOLDEN KERNEL POLICY'
  sudo dnf upgrade --refresh -y
  ui_check PASS 'Fedora packages' 'upgrade transaction completed'
}

apply_flatpak() {
  if command -v flatpak >/dev/null 2>&1; then
    ui_banner 'FEDORA WORKSTATION UPDATE' 'FLATPAK APPLICATIONS'
    flatpak update -y
    ui_check PASS 'Flatpak applications' 'update transaction completed'
  else
    ui_check EXPECTED 'Flatpak applications' 'flatpak unavailable'
  fi
}

post_update_health() {
  local doctor_rc=0
  ui_banner 'FEDORA WORKSTATION UPDATE' 'POST-UPDATE HEALTH'
  if "$REPO_ROOT/diagnostic.sh"; then
    ui_check PASS 'Post-update diagnostic' 'global doctor completed'
  else
    doctor_rc=$?
    ui_check WARN 'Post-update diagnostic' "doctor rc=$doctor_rc — inspect before certification"
  fi

  if command -v needs-restarting >/dev/null 2>&1; then
    if needs-restarting -r >/dev/null 2>&1; then
      ui_check PASS 'Reboot' 'not required by needs-restarting'
    else
      ui_check WARN 'Reboot' 'required/recommended after this update'
    fi
  else
    ui_check EXPECTED 'Reboot detector' 'needs-restarting unavailable'
  fi
  return "$doctor_rc"
}

mode="${1:---check}"
require_fedora

case "$mode" in
  --check)
    ui_banner 'FEDORA WORKSTATION UPDATE' 'READ-ONLY UPDATE OVERVIEW'
    dnf_rc=0
    check_dnf || dnf_rc=$?
    check_flatpak
    check_firmware
    ((dnf_rc == 0 || dnf_rc == 100)) || exit "$dnf_rc"
    ;;
  --apply)
    require_baremetal_update
    mandatory_preupdate_backup
    apply_dnf
    apply_flatpak
    check_firmware
    post_update_health || exit "$EXIT_POSTCHECK_FAILED"
    ;;
  --dnf-only)
    require_baremetal_update
    mandatory_preupdate_backup
    apply_dnf
    post_update_health || exit "$EXIT_POSTCHECK_FAILED"
    ;;
  --flatpak-only)
    require_baremetal_update
    apply_flatpak
    ;;
  --firmware-check)
    check_firmware
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit "$EXIT_USAGE"
    ;;
esac
