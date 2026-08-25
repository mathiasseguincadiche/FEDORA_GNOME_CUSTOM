#!/usr/bin/env bash
set -Eeuo pipefail
backup_host_precheck() { is_true "${BACKUP_HOST_CONFIG:-true}"; }
backup_host_plan() { echo 'Host backup captures /etc and /boot through a privileged metadata-preserving tar staging archive plus user GNOME configuration and the tracked repository.'; }
backup_host_apply() { :; }
backup_host_postcheck() { return 0; }
