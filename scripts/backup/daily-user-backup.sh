#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

REPO_ROOT="${FEDORA_GNOME_CUSTOM_REPO:-}"
if [[ -z "$REPO_ROOT" || ! -r "$REPO_ROOT/lib/bootstrap.sh" ]]; then
  echo 'FEDORA_GNOME_CUSTOM_REPO does not point to a valid checkout.' >&2
  exit 20
fi
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

mkdir -p "$STATE_ROOT"
repo="$(backup_runtime_resolve_repository 2>/dev/null || true)"
password_file="$(backup_runtime_require_password 2>/dev/null || true)"
if [[ -z "$repo" || -z "$password_file" ]]; then
  printf 'utc=%s\nreason=repository-or-password-unavailable\n' "$(date -u +%FT%TZ)" > "$STATE_ROOT/last-daily-backup-skipped"
  exit 0
fi

backup_runtime_export_env "$repo" "$password_file"
if ! restic cat config >/dev/null 2>&1; then
  printf 'utc=%s\nreason=repository-unreachable\n' "$(date -u +%FT%TZ)" > "$STATE_ROOT/last-daily-backup-skipped"
  exit 0
fi

declare -a sources=()
read -r -a configured_paths <<<"${DAILY_BACKUP_PATHS:-Documents Desktop Pictures Videos Music Projects Development .config .ssh .gnupg}"
for rel in "${configured_paths[@]}"; do
  [[ "$rel" != /* && "/$rel/" != *'/../'* ]] || continue
  [[ -e "$HOME/$rel" ]] && sources+=("$HOME/$rel")
done
((${#sources[@]} > 0)) || {
  printf 'utc=%s\nreason=no-configured-source-exists\n' "$(date -u +%FT%TZ)" > "$STATE_ROOT/last-daily-backup-skipped"
  exit 0
}

exclude_secrets="$HOME/.config/fedora-gnome-custom/secrets"
restic backup --tag fedora-gnome-custom-daily --exclude "$exclude_secrets" "${sources[@]}"
snap="$(restic snapshots --tag fedora-gnome-custom-daily --latest 1 --json | jq -r '.[0].id // empty')"
[[ "$snap" =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'Invalid daily snapshot id.' >&2; exit 40; }

printf 'snapshot=%s\nutc=%s\nrepository=%s\n' "$snap" "$(date -u +%FT%TZ)" "$repo" > "$STATE_ROOT/last-daily-backup.ok"
chmod 0600 "$STATE_ROOT/last-daily-backup.ok"
rm -f "$STATE_ROOT/last-daily-backup-skipped"

if command -v notify-send >/dev/null 2>&1; then
  notify-send 'Sauvegarde Fedora' 'Sauvegarde quotidienne chiffrée terminée.' >/dev/null 2>&1 || true
fi
