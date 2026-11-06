#!/usr/bin/env bash
set -Eeuo pipefail

# Verdict final de la phase 0 : le marqueur de certification doit correspondre à l'empreinte matérielle et BIOS courante avant la convergence réelle.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
baseline_validation_precheck() { return 0; }
baseline_validation_plan() { echo 'Final Phase 0 verdict: the certification marker must match the current hardware/BIOS fingerprint before real workstation convergence.'; }
baseline_validation_apply() { log_info BASELINE 'read-only final baseline validation'; }
baseline_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  baseline_certification_valid || return "$EXIT_POSTCHECK_FAILED"
}
