#!/usr/bin/env bash
set -Eeuo pipefail

# Validation GNOME : pile GNOME/Nautilus/portails et session Wayland courante quand l'exécution a lieu dans GNOME.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
gnome_validation_precheck() { :; }
gnome_validation_plan() { echo 'Validate GNOME/Nautilus/portal stack and current Wayland session when running inside GNOME.'; }
gnome_validation_apply() { :; }
gnome_validation_postcheck() { is_true "${DRY_RUN:-true}" && return 0; "$REPO_ROOT/diagnostics/gnome-doctor" --quiet; }
