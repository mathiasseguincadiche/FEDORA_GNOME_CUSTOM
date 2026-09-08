#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [[ -n "${FEDORA_GNOME_CUSTOM_RUNTIME_ROOT:-}" ]]; then
  helper="$FEDORA_GNOME_CUSTOM_RUNTIME_ROOT/lib/backup_runtime_bundle.sh"
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  helper="$REPO_ROOT/lib/backup_runtime_bundle.sh"
fi
[[ -r "$helper" ]] || { echo "Missing backup runtime helper: $helper" >&2; exit 20; }
# shellcheck disable=SC1090
source "$helper"
backup_runtime_bundle_init

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

data_mount_validated=false
require_persistent_data_mount() {
  local target fstype root_source data_source
  [[ "$data_mount_validated" == true ]] && return 0
  command -v findmnt >/dev/null 2>&1 || { echo 'findmnt is required for persistent-data backup validation.' >&2; exit "$EXIT_PRECHECK_FAILED"; }
  target="$(findmnt -n -T /data -o TARGET 2>/dev/null || true)"
  fstype="$(findmnt -n -T /data -o FSTYPE 2>/dev/null || true)"
  root_source="$(findmnt -n -T / -o SOURCE 2>/dev/null || true)"
  data_source="$(findmnt -n -T /data -o SOURCE 2>/dev/null || true)"
  [[ "$target" == /data && "$fstype" == ext4 && -n "$data_source" && "$data_source" != "$root_source" ]] || {
    echo 'Refusing persistent-data backup: /data is not the dedicated EXT4 second T705.' >&2
    exit "$EXIT_PRECHECK_FAILED"
  }
  data_mount_validated=true
}

declare -a sources=()
add_source() {
  local candidate="$1" existing
  [[ -n "$candidate" ]] || return 0
  case "$candidate" in
    "$HOME"/*) ;;
    /data/Documents|/data/Projets) require_persistent_data_mount ;;
    *)
      echo "Refusing daily backup source outside approved user-data roots: $candidate" >&2
      exit "$EXIT_CONFIG_FAILED"
      ;;
  esac
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

configured_extra="${DAILY_BACKUP_EXTRA_PATHS:-${DAILY_BACKUP_PATHS:-/data/Projets Development .config .ssh .gnupg}}"
read -r -a configured_paths <<<"$configured_extra"
for entry in "${configured_paths[@]}"; do
  if [[ "$entry" == /* ]]; then
    case "$entry" in
      /data/Documents|/data/Projets) add_source "$entry" ;;
      *) echo "Refusing unsafe absolute DAILY_BACKUP_EXTRA_PATHS entry: $entry" >&2; exit "$EXIT_CONFIG_FAILED" ;;
    esac
  else
    [[ "/$entry/" != *'/../'* ]] || {
      echo "Refusing unsafe DAILY_BACKUP_EXTRA_PATHS entry: $entry" >&2
      exit "$EXIT_CONFIG_FAILED"
    }
    add_source "$HOME/$entry"
  fi
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
  printf 'runtime_sha=%s\n' "$FEDORA_GNOME_CUSTOM_RUNTIME_SHA"
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
