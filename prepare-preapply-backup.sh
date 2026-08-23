#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap

[[ -n "${BACKUP_REPOSITORY:-}" && -n "${BACKUP_PASSWORD_FILE:-}" ]] || { echo 'Configure BACKUP_REPOSITORY and BACKUP_PASSWORD_FILE in config/local.conf.' >&2; exit 20; }
[[ -r "$BACKUP_PASSWORD_FILE" ]] || { echo 'BACKUP_PASSWORD_FILE is not readable.' >&2; exit 20; }

if ! command_exists restic || ! command_exists jq; then
  echo 'Backup preparation requires restic and jq; installing these Fedora packages now.'
  sudo dnf -y install restic jq
fi

export RESTIC_REPOSITORY="$BACKUP_REPOSITORY" RESTIC_PASSWORD_FILE="$BACKUP_PASSWORD_FILE"
if ! restic snapshots >/dev/null 2>&1; then
  echo 'Restic repository is not initialized or not reachable. Initializing only the configured repository.'
  restic init
fi

paths=(/etc /boot "$HOME/.config")
[[ -d "$HOME/.local/share/gnome-shell" ]] && paths+=("$HOME/.local/share/gnome-shell")
restic backup --tag fedora-gnome-custom-preapply "${paths[@]}"
restic check --read-data-subset=1/20
snap="$(restic snapshots --tag fedora-gnome-custom-preapply --latest 1 --json | jq -r '.[0].short_id // empty')"
[[ -n "$snap" ]] || { echo 'No verified snapshot found.' >&2; exit 40; }
printf 'snapshot=%s\ncommit=%s\nutc=%s\n' "$snap" "$(repo_commit)" "$(date -u +%FT%TZ)" > "$STATE_ROOT/preapply-backup.ok"
echo "Verified pre-APPLY backup: $snap"
