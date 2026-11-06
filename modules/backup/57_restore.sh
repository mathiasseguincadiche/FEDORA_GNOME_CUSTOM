#!/usr/bin/env bash
set -Eeuo pipefail

# Restauration : d'abord en staging (lister, vérifier, restaurer dans un dossier vide choisi par l'opérateur) ; jamais d'écrasement automatique en place.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
backup_restore_precheck() { [[ -x "$REPO_ROOT/scripts/backup/restore.sh" || -r "$REPO_ROOT/scripts/backup/restore.sh" ]]; }
backup_restore_plan() { echo 'Restore workflow is staging-first: list/verify/restore into an operator-selected empty directory; no automatic in-place overwrite of host or active VM storage.'; }
backup_restore_apply() { :; }
backup_restore_postcheck() { [[ -r "$REPO_ROOT/scripts/backup/restore.sh" ]]; }
