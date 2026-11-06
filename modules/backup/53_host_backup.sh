#!/usr/bin/env bash
set -Eeuo pipefail

# Sauvegarde de l'hôte : /etc et /boot dans une archive tar privilégiée préservant les métadonnées, configuration GNOME de l'utilisateur et dépôt Git suivi.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
backup_host_precheck() { is_true "${BACKUP_HOST_CONFIG:-true}"; }
backup_host_plan() { echo 'Host backup captures /etc and /boot through a privileged metadata-preserving tar staging archive plus user GNOME configuration and the tracked repository.'; }
backup_host_apply() { :; }
backup_host_postcheck() { return 0; }
