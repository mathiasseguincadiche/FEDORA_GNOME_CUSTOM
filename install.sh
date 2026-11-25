#!/usr/bin/env bash
# Runs the modules of manifests/module-plan.conf in order. --dry-run (default) neutralises
# every mutation and writes the dry-run proof; --collect-all visits every module without
# writing it. --apply opens the apply gate (lib/apply_gate.sh) first, then converges the
# system. Reference: docs/ARCHITECTURE.md#contrat-dexécution.
set -Eeuo pipefail
shopt -s inherit_errexit
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---dry-run}"
[[ "$MODE" == '--dry-run' || "$MODE" == '--apply' ]] || { echo "Usage: $0 [--dry-run|--apply] [--collect-all]" >&2; exit 2; }
ORCH_COLLECT_ALL=false
if [[ $# -gt 1 ]]; then
  [[ $# -eq 2 && "$MODE" == --dry-run && "$2" == --collect-all ]] || { echo '--collect-all is only valid with --dry-run' >&2; exit 2; }
  ORCH_COLLECT_ALL=true
fi
source "$REPO_ROOT/lib/install_lock.sh"
install_lock_acquire
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/apply_incident.sh"
if [[ "$MODE" == --dry-run ]]; then
  apply_gate_invalidate_dryrun || { ui_error "Cannot invalidate previous dry-run proof"; exit "$EXIT_SECURITY_BLOCK"; }
fi
module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate

if [[ "$MODE" == '--dry-run' ]]; then
  DRY_RUN=true; export DRY_RUN
  ui_banner 'FEDORA WORKSTATION CONTROL' 'NON-MUTATING PREFLIGHT / CONVERGENCE PLAN'
  dryrun_identity=''
  if [[ "$ORCH_COLLECT_ALL" != true ]]; then
    dryrun_identity="$(apply_gate_dryrun_identity)" || { ui_error 'Cannot capture initial dry-run identity'; exit "$EXIT_SECURITY_BLOCK"; }
  fi
  if orchestrator_run_all; then
    report="$(orchestrator_report)"
    if [[ "$ORCH_COLLECT_ALL" != true ]]; then
      apply_gate_complete_dryrun "$dryrun_identity" || { ui_error 'Dry-run identity changed or evidence publication failed; no APPLY proof'; exit "$EXIT_SECURITY_BLOCK"; }
    fi
    if [[ "$ORCH_COLLECT_ALL" == true ]]; then
      ui_summary 'DIAGNOSTIC PASS' 'NO MUTATIONS EXECUTED — RUN FULL DRY-RUN BEFORE APPLY' "$report" "$LOG_DIR"
    else
      ui_summary 'PREFLIGHT PASS' 'NO MUTATIONS EXECUTED — PREPARE VERIFIED BACKUP, THEN APPLY' "$report" "$LOG_DIR"
    fi
    exit 0
  else
    rc=$?
    report="$(orchestrator_report)"
    ui_summary "PREFLIGHT FAIL rc=$rc" 'FIX BEFORE APPLY' "$report" "$LOG_DIR"
    exit "$rc"
  fi
fi

DRY_RUN=false; export DRY_RUN
ui_banner 'FEDORA WORKSTATION CONTROL' 'PROTECTED REAL APPLY'
apply_incident_require_clear || exit "$EXIT_SECURITY_BLOCK"
apply_gate_open
apply_incident_begin || { ui_error "Cannot persist APPLY incident and original Borg point; no modules started"; exit "$EXIT_SECURITY_BLOCK"; }
apply_gate_invalidate_dryrun || { ui_error "Cannot consume dry-run proof; no modules started"; exit "$EXIT_SECURITY_BLOCK"; }
if orchestrator_run_all; then
  report="$(orchestrator_report)"
  apply_incident_close completed || { ui_error 'Cannot finalize persistent APPLY record; inspect incident before retry'; exit "$EXIT_SECURITY_BLOCK"; }
  ui_summary 'REAL APPLY COMPLETED' 'RUN ./diagnostic.sh AND REBOOT WHEN REQUESTED' "$report" "$LOG_DIR"
  exit 0
else
  rc=$?
  report="$(orchestrator_report)"
  ui_summary "REAL APPLY FAILED rc=$rc" 'SYSTEM MAY BE PARTIALLY CONVERGED — INSPECT REPORT/LOGS BEFORE RETRY OR REBOOT' "$report" "$LOG_DIR"
  exit "$rc"
fi
