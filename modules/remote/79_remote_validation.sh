#!/usr/bin/env bash
set -Eeuo pipefail

# Validation de l'accès distant : tailnet non connecté = avertissement ; la qualification physique (cycles WoL, streaming) reste une mesure de Gate 3.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).

source "$REPO_ROOT/lib/remote_access.sh"

remote_validation_precheck() { return 0; }

remote_validation_plan() {
  if remote_enabled; then
    echo 'Run the remote-access doctor after convergence. A tailnet that is not logged in yet is a warning; physical qualification (Wake-on-LAN cycles, streaming) stays a Gate 3 measurement.'
  else
    echo 'Remote-access validation skipped because the optional profile is disabled.'
  fi
}

remote_validation_apply() { return 0; }

remote_validation_postcheck() {
  remote_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/remote-doctor" --quiet
}
