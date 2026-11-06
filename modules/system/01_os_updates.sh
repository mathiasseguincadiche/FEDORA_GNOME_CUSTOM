#!/usr/bin/env bash
set -Eeuo pipefail

# Rafraîchir les métadonnées Fedora et aligner tous les paquets RPM installés sur les mises à jour de la version sélectionnée.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
system_updates_precheck() { command_exists dnf; }
system_updates_plan() { echo 'Refresh Fedora metadata and converge all installed RPM packages to current selected Fedora release updates.'; }
system_updates_apply() {
  local -a packages=()
  mapfile -t packages < <(sed -E '/^[[:space:]]*(#|$)/d' "$REPO_ROOT/manifests/packages-system.txt")
  (( ${#packages[@]} > 0 )) || return "$EXIT_CONFIG_FAILED"
  run_mutating SYSTEM sudo dnf -y install "${packages[@]}" || return $?
  run_mutating SYSTEM sudo dnf -y upgrade --refresh
}
system_updates_postcheck() { is_true "${DRY_RUN:-true}" && return 0; sudo dnf -q check; }
