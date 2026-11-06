#!/usr/bin/env bash
set -Eeuo pipefail

# Validation du domaine sauvegardes : politique fermée par défaut, outillage Borg et protocoles de restauration protégés ; les contrôles à l'exécution relèvent de backup-doctor.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
backup_validation_precheck() { [[ -r "$REPO_ROOT/diagnostics/backup-doctor" ]]; }
backup_validation_plan() { echo 'Validate fail-closed backup/recovery policy, Borg tooling and protected recovery helpers. Repository runtime checks are performed by backup-doctor outside dry-run.'; }
backup_validation_apply() { :; }
backup_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  bash "$REPO_ROOT/diagnostics/backup-doctor" --policy-only
}
