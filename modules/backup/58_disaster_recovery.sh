#!/usr/bin/env bash
set -Eeuo pipefail

# Reprise après sinistre : vérifier le dépôt et l'instantané, émettre la séquence de reconstruction sans automatisation destructive ; les VM ne viennent que des exportations manuelles du propriétaire.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
backup_dr_precheck() { [[ -r "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ]]; }
backup_dr_plan() { echo 'Disaster-recovery helper verifies repository/snapshot availability and emits a rebuild sequence for Fedora, GNOME, the host and final diagnostics without destructive automation; VMs come only from the separate manual exports of the owner.'; }
backup_dr_apply() { :; }
backup_dr_postcheck() { [[ -r "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ]]; }
