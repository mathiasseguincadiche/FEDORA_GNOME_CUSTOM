#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

GATE2_CONFIRMATION='JE_VALIDE_VISUELLEMENT_GATE2'

usage() {
  cat <<'EOF'
Usage: scripts/validation/gate2-virtualbox.sh [plan|apply|check|sign|status]

plan    Show the exact Gate 2 desktop validation scope.
apply   Converge the VirtualBox-only GNOME/Nautilus/Ptyxis desktop subset.
check   Run automated Gate 2 doctors without signing the visual checklist.
sign    Re-run doctors, require explicit human visual sign-off, then create Gate 2 proof.
status  Show current imported Gate 1 and local Gate 2 proof state.

Import the matching Gate 1 proof first with:
  ./control.sh validate import /path/to/gate1-<commit>.json
EOF
}

gate2_require_runtime() {
  runtime_is_virtualbox || {
    ui_error "Gate 2 requires Oracle VirtualBox; runtime=$(runtime_environment) vendor=$(runtime_vm_vendor_detect 2>/dev/null || printf none)"
    return "$EXIT_SECURITY_BLOCK"
  }
  validation_require_fedora44 || {
    ui_error 'Gate 2 requires Fedora Linux 44'
    return "$EXIT_PRECHECK_FAILED"
  }
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || {
    ui_error 'Gate 2 requires an active GNOME session'
    return "$EXIT_PRECHECK_FAILED"
  }
  [[ "${XDG_SESSION_TYPE:-}" == wayland ]] || {
    ui_error "Gate 2 requires Wayland; detected ${XDG_SESSION_TYPE:-unknown}"
    return "$EXIT_PRECHECK_FAILED"
  }
  validation_require_clean_source || return $?
  validation_require_imported_gate 1 || {
    ui_error 'A current imported Gate 1 PASS proof is mandatory before Gate 2'
    return "$EXIT_PRECHECK_FAILED"
  }
}

gate2_plan() {
  cat <<'EOF'
GATE 2 — VIRTUALBOX DESKTOP VALIDATION

AUTOMATED SCOPE
- Fedora 44 + GNOME Shell 50 + Wayland + Oracle VirtualBox identity.
- GNOME core and portal packages.
- Nautilus + GVfs + Sushi + File Roller integration and user prewarm service.
- Curated GTK4/libadwaita application set including Ptyxis.
- GNOME window settings.
- DING, Show Desktop Plus and Resource Monitor pinned/reviewed extensions.
- Nautilus integration doctor.
- Ptyxis doctor.
- Portal doctor.
- VirtualBox GNOME LAB doctor.

MANUAL VISUAL SIGN-OFF
- GNOME Shell opens without crash or obvious rendering defect.
- DING desktop icons behave as expected.
- Show Desktop Plus button and Super+D work.
- Resource Monitor is visible and readable in the top bar.
- Nautilus opens normally, browses folders and exposes expected integration.
- Ptyxis launches normally from GNOME and from the intended desktop workflow.
- No extension error banner, repeated shell crash or obvious layout regression.

EXPLICITLY DEFERRED TO GATE 3
- Arc B580 native xe driver, ReBAR, PCIe x8 and physical telemetry.
- T705 SMART/PCIe x4 and storage I/O.
- Physical EDID, 1440p/~240 Hz, HDR/VRR/display recovery.
- BIOS/UEFI, firmware/microcode and physical suspend/resume.
- KVM host certification and production Restic/final Golden certification.
EOF
}

gate2_apply() {
  gate2_require_runtime || return $?
  ui_banner 'GATE 2 — VIRTUALBOX' 'DESKTOP CONVERGENCE'
  "$REPO_ROOT/scripts/lab/apply-gnome-virtualbox.sh" --apply
  ui_summary 'GATE 2 APPLY COMPLETE' 'LOG OUT/IN IF GNOME REQUESTS IT, THEN RUN CHECK AND SIGN' "$REPORT_ROOT" "$LOG_DIR"
}

gate2_check() {
  gate2_require_runtime || return $?
  ui_banner 'GATE 2 — VIRTUALBOX' 'AUTOMATED DESKTOP CHECK'
  "$REPO_ROOT/diagnostics/virtualbox-gnome-lab-doctor"
  "$REPO_ROOT/diagnostics/nautilus-integration-doctor" --quiet
  "$REPO_ROOT/diagnostics/ptyxis-doctor" --quiet
  "$REPO_ROOT/diagnostics/portal-doctor" --quiet
  ui_check OK 'Gate 2 automated checks' 'GNOME/Nautilus/Ptyxis/portal PASS'
}

gate2_sign() {
  local imported_gate1 predecessor proof answer
  gate2_require_runtime || return $?
  gate2_check || return $?
  [[ -t 0 && -t 1 ]] || {
    ui_error 'Gate 2 visual sign-off requires an interactive terminal'
    return "$EXIT_SECURITY_BLOCK"
  }

  gate2_plan
  printf '\nAfter physically checking every MANUAL VISUAL SIGN-OFF item, type exactly:\n  %s\n> ' "$GATE2_CONFIRMATION"
  read -r answer
  [[ "$answer" == "$GATE2_CONFIRMATION" ]] || {
    ui_error 'Gate 2 visual sign-off was not confirmed'
    return "$EXIT_SECURITY_BLOCK"
  }

  imported_gate1="$(validation_imported_proof_path 1)"
  predecessor="$(validation_file_sha256 "$imported_gate1")"
  proof="$(validation_write_proof 2 virtualbox "$predecessor" PASS 'virtualbox_doctor=PASS;nautilus=PASS;ptyxis=PASS;portal=PASS;manual_visual=PASS;physical_hardware=DEFERRED')"
  ui_check OK 'Gate 2 proof' "$proof"
  ui_meta 'Gate 1 predecessor SHA256' "$predecessor"
  ui_summary 'GATE 2 PASS' 'EXPORT GATE 1 + GATE 2 PROOFS TO THE BARE-METAL INSTALLATION' "$proof" "$LOG_DIR"
}

gate2_status() {
  local gate1 local_gate2
  gate1="$(validation_imported_proof_path 1)"
  local_gate2="$(validation_gate_proof_path 2)"
  ui_banner 'GATE 2 — VIRTUALBOX' 'STATUS'
  if validation_verify_proof "$gate1" 1; then
    ui_check OK 'Imported Gate 1' "$gate1"
  else
    ui_check WARN 'Imported Gate 1' 'missing or stale'
  fi
  if validation_verify_proof "$local_gate2" 2; then
    ui_check OK 'Local Gate 2 proof' "$local_gate2"
    ui_meta SHA256 "$(validation_file_sha256 "$local_gate2")"
  else
    ui_check WARN 'Local Gate 2 proof' 'not signed for current commit/module plan'
  fi
}

case "${1:-status}" in
  plan) gate2_plan ;;
  apply) gate2_apply ;;
  check) gate2_check ;;
  sign) gate2_sign ;;
  status) gate2_status ;;
  -h|--help) usage ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac
