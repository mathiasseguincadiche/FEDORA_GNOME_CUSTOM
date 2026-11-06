#!/usr/bin/env bash
set -Eeuo pipefail

# Validation de la politique de performance du poste, sans exiger sched_ext expérimental ni mutation du scheduler NVMe.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
performance_validation_precheck() { return 0; }
performance_validation_plan() { echo 'Validate Fedora Linux runtime performance policy without requiring experimental sched_ext or NVMe scheduler mutations.'; }
performance_validation_apply() { return 0; }
performance_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/performance-doctor" --quiet --core
}
