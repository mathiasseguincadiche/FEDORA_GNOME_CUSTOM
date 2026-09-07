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
sign    Re-run doctors, execute the interactive GNOME UX matrix, require explicit sign-off, then create Gate 2 proof.
status  Show current imported Gate 1 and local Gate 2 proof state.

Import the matching Gate 1 proof first with:
  ./control.sh validate import /path/to/gate1-<commit>.json
EOF
}

gate2_require_runtime() {
  runtime_is_virtualbox || { ui_error "Gate 2 requires Oracle VirtualBox; runtime=$(runtime_environment) vendor=$(runtime_vm_vendor_detect 2>/dev/null || printf none)"; return "$EXIT_SECURITY_BLOCK"; }
  validation_require_fedora44 || { ui_error 'Gate 2 requires Fedora Linux 44'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || { ui_error 'Gate 2 requires an active GNOME session'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { ui_error "Gate 2 requires Wayland; detected ${XDG_SESSION_TYPE:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
  validation_require_clean_source || return $?
  validation_require_imported_gate 1 || { ui_error 'A current imported Gate 1 PASS proof is mandatory before Gate 2'; return "$EXIT_PRECHECK_FAILED"; }
}

gate2_plan() {
  cat <<'EOF'
GATE 2 — VIRTUALBOX DESKTOP VALIDATION

AUTOMATED SCOPE
- Fedora 44 + GNOME Shell 50 + Wayland + Oracle VirtualBox identity.
- GNOME runtime health: Shell/Mutter/GJS critical journal signals and extension runtime states.
- Nautilus + LocalSearch + GVfs + Sushi + File Roller integration and user prewarm service.
- LocalSearch service, indexed-locations query and real searchable HOME canary.
- Fedora Nautilus → Ptyxis binding plus a real Ptyxis working-directory canary including spaces.
- Curated GTK4/libadwaita application set and deterministic native default-app MIME associations.
- XDG portal substrate plus real request creation for ScreenCast.
- DING, Show Desktop Plus and Resource Monitor pinned/reviewed extensions.

INTERACTIVE GNOME UX MATRIX
- Overview, dock/favorites and window layout.
- DING desktop surface and Trash.
- Show Desktop Plus button + Super+D.
- Resource Monitor readability.
- Nautilus navigation/previews/search.
- Nautilus “Open in Console” → Ptyxis with the exact current directory.
- Native default applications.
- Portal Notification/OpenURI/FileChooser and ScreenCast availability.

EXPLICITLY DEFERRED TO GATE 3
- Arc B580 native xe driver, physical telemetry and Vulkan soak.
- T705 SMART/PCIe/storage I/O.
- Physical EDID/HDR/VRR/display recovery.
- BIOS/UEFI, firmware/microcode and physical suspend/resume.
- Live Nautilus access to production KVM Ubuntu SFTP + Windows SMB.
- Production Restic/final Golden certification.
EOF
}

gate2_apply() {
  gate2_require_runtime || return $?
  ui_banner 'GATE 2 — VIRTUALBOX' 'DESKTOP CONVERGENCE'
  "$REPO_ROOT/scripts/lab/apply-gnome-virtualbox.sh" --apply
  if is_true "${GNOME_DEFAULT_APPS_ENABLED:-true}"; then "$REPO_ROOT/scripts/gnome/configure-default-apps.sh" gate2; fi
  ui_summary 'GATE 2 APPLY COMPLETE' 'LOG OUT/IN IF GNOME REQUESTS IT, THEN RUN CHECK AND SIGN' "$REPORT_ROOT" "$LOG_DIR"
}

gate2_check() {
  gate2_require_runtime || return $?
  ui_banner 'GATE 2 — VIRTUALBOX' 'AUTOMATED DESKTOP CHECK'
  "$REPO_ROOT/diagnostics/virtualbox-gnome-lab-doctor"
  "$REPO_ROOT/diagnostics/nautilus-integration-doctor" --quiet
  "$REPO_ROOT/diagnostics/ptyxis-doctor" --quiet
  "$REPO_ROOT/diagnostics/gnome-desktop-integration-doctor" --quiet --functional --preflight
  "$REPO_ROOT/diagnostics/portal-doctor" --quiet
  ui_check OK 'Gate 2 automated checks' 'GNOME runtime/Nautilus/LocalSearch/Ptyxis/default-apps/portal PASS'
}

gate2_sign() {
  local imported_gate1 predecessor proof answer ux_marker
  gate2_require_runtime || return $?
  gate2_check || return $?
  [[ -t 0 && -t 1 ]] || { ui_error 'Gate 2 visual sign-off requires an interactive terminal'; return "$EXIT_SECURITY_BLOCK"; }
  "$REPO_ROOT/scripts/validation/gnome-ux-matrix.sh" gate2 || return $?
  ux_marker="$STATE_ROOT/validation/gnome-ux-gate2-$(repo_commit).ok"
  [[ -s "$ux_marker" ]] || { ui_error 'Gate 2 GNOME UX evidence missing'; return "$EXIT_PRECHECK_FAILED"; }
  gate2_plan
  printf '\nAfter completing the GNOME UX matrix, type exactly:\n  %s\n> ' "$GATE2_CONFIRMATION"
  read -r answer
  [[ "$answer" == "$GATE2_CONFIRMATION" ]] || { ui_error 'Gate 2 visual sign-off was not confirmed'; return "$EXIT_SECURITY_BLOCK"; }
  imported_gate1="$(validation_imported_proof_path 1)"; predecessor="$(validation_file_sha256 "$imported_gate1")"
  proof="$(validation_write_proof 2 virtualbox "$predecessor" PASS 'virtualbox_doctor=PASS;gnome_runtime=PASS;localsearch=PASS;nautilus=PASS;nautilus_ptyxis=PASS;ptyxis=PASS;default_apps=PASS;portal_functional=PASS;gnome_ux=PASS;manual_visual=PASS;physical_hardware=DEFERRED')"
  ui_check OK 'Gate 2 proof' "$proof"; ui_meta 'Gate 1 predecessor SHA256' "$predecessor"; ui_meta 'GNOME UX evidence' "$ux_marker"
  ui_summary 'GATE 2 PASS' 'EXPORT GATE 1 + GATE 2 PROOFS TO THE BARE-METAL INSTALLATION' "$proof" "$LOG_DIR"
}

gate2_status() {
  local gate1 local_gate2 ux_marker
  gate1="$(validation_imported_proof_path 1)"; local_gate2="$(validation_gate_proof_path 2)"; ux_marker="$STATE_ROOT/validation/gnome-ux-gate2-$(repo_commit).ok"
  ui_banner 'GATE 2 — VIRTUALBOX' 'STATUS'
  if validation_verify_proof "$gate1" 1; then ui_check OK 'Imported Gate 1' "$gate1"; else ui_check WARN 'Imported Gate 1' 'missing or stale'; fi
  if validation_verify_proof "$local_gate2" 2; then ui_check OK 'Local Gate 2 proof' "$local_gate2"; ui_meta SHA256 "$(validation_file_sha256 "$local_gate2")"; else ui_check WARN 'Local Gate 2 proof' 'not signed for current commit/module plan'; fi
  if [[ -s "$ux_marker" ]]; then ui_check OK 'GNOME UX matrix' "$ux_marker"; else ui_check WARN 'GNOME UX matrix' 'not completed for current commit'; fi
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
