#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

REPO_ROOT="${FEDORA_GNOME_CUSTOM_REPO:-}"
if [[ -z "$REPO_ROOT" || ! -r "$REPO_ROOT/lib/bootstrap.sh" ]]; then
  echo 'FEDORA_GNOME_CUSTOM_REPO does not point to a valid checkout.' >&2
  exit 20
fi
command -v git >/dev/null 2>&1 || { echo 'git is required to validate the installed daily-backup runtime.' >&2; exit 20; }
current_sha="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
expected_sha="${FEDORA_GNOME_CUSTOM_APPLIED_SHA:-$current_sha}"
[[ "$current_sha" =~ ^[0-9a-fA-F]{40}$ && "$expected_sha" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Daily backup cannot prove its repository SHA.' >&2; exit 20; }
[[ "$current_sha" == "$expected_sha" ]] || { echo "Daily backup blocked: checkout SHA $current_sha differs from applied SHA $expected_sha. Re-APPLY the reviewed version." >&2; exit 20; }
git -C "$REPO_ROOT" diff --quiet -- . || { echo 'Daily backup blocked: tracked checkout files differ from the applied version.' >&2; exit 20; }
git -C "$REPO_ROOT" diff --cached --quiet -- . || { echo 'Daily backup blocked: staged checkout changes differ from the applied version.' >&2; exit 20; }

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
add_source() {
  local candidate="$1" existing
  [[ -n "$candidate" ]] || return 0
  [[ "$candidate" == "$HOME/"* ]] || {
    echo "Refusing daily backup source outside HOME: $candidate" >&2
    exit "$EXIT_CONFIG_FAILED"
  }
  [[ -e "$candidate" ]] || return 0
  for existing in "${sources[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  sources+=("$candidate")
}

configured_xdg="${DAILY_BACKUP_XDG_DIRS:-DESKTOP DOCUMENTS PICTURES VIDEOS MUSIC}"
if [[ -n "$configured_xdg" ]]; then
  command -v xdg-user-dir >/dev/null 2>&1 || {
    echo 'xdg-user-dir is required for locale-safe daily backups.' >&2
    exit "$EXIT_PRECHECK_FAILED"
  }
  read -r -a xdg_dirs <<<"$configured_xdg"
  for key in "${xdg_dirs[@]}"; do
    case "$key" in
      DESKTOP|DOCUMENTS|PICTURES|VIDEOS|MUSIC) ;;
      *) echo "Unsupported DAILY_BACKUP_XDG_DIRS entry: $key" >&2; exit "$EXIT_CONFIG_FAILED" ;;
    esac
    if ! resolved="$(xdg-user-dir "$key" 2>/dev/null)" || [[ -z "$resolved" ]]; then
      echo "Cannot resolve XDG user directory: $key" >&2
      exit "$EXIT_PRECHECK_FAILED"
    fi
    [[ "$resolved" != "$HOME" ]] || {
      echo "Refusing ambiguous XDG $key mapping to HOME; configure a dedicated user directory." >&2
      exit "$EXIT_CONFIG_FAILED"
    }
    add_source "$resolved"
  done
fi

configured_extra="${DAILY_BACKUP_EXTRA_PATHS:-${DAILY_BACKUP_PATHS:-Projects Development .config .ssh .gnupg}}"
read -r -a configured_paths <<<"$configured_extra"
for rel in "${configured_paths[@]}"; do
  [[ "$rel" != /* && "/$rel/" != *'/../'* ]] || {
    echo "Refusing unsafe DAILY_BACKUP_EXTRA_PATHS entry: $rel" >&2
    exit "$EXIT_CONFIG_FAILED"
  }
  add_source "$HOME/$rel"
done

((${#sources[@]} > 0)) || {
  printf 'utc=%s\nreason=no-configured-source-exists\n' "$(date -u +%FT%TZ)" > "$STATE_ROOT/last-daily-backup-skipped"
  exit 0
}

exclude_secrets="$HOME/.config/fedora-gnome-custom/secrets"
restic backup --tag fedora-gnome-custom-daily --exclude "$exclude_secrets" "${sources[@]}"
snap="$(restic snapshots --tag fedora-gnome-custom-daily --latest 1 --json | jq -r '.[0].id // empty')"
[[ "$snap" =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'Invalid daily snapshot id.' >&2; exit 40; }

{
  printf 'snapshot=%s\n' "$snap"
  printf 'commit=%s\n' "$current_sha"
  printf 'utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'repository=%s\n' "$repo"
  printf 'source_count=%s\n' "${#sources[@]}"
  for source in "${sources[@]}"; do printf 'source=%s\n' "$source"; done
} > "$STATE_ROOT/last-daily-backup.ok"
chmod 0600 "$STATE_ROOT/last-daily-backup.ok"
rm -f "$STATE_ROOT/last-daily-backup-skipped"

if command -v notify-send >/dev/null 2>&1; then
  notify-send 'Sauvegarde Fedora' 'Sauvegarde quotidienne chiffrée terminée.' >/dev/null 2>&1 || true
fi
