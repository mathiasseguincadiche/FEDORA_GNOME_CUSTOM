#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
source "$ROOT/lib/backup_runtime.sh"
BACKUP_RESTORE_STAGING_ROOT="$tmp/staging"
mkdir -p "$BACKUP_RESTORE_STAGING_ROOT" "$tmp/outside"
ln -s "$tmp/outside" "$BACKUP_RESTORE_STAGING_ROOT/link"
backup_runtime_restore_target_valid "$BACKUP_RESTORE_STAGING_ROOT/snapshot"
for target in /etc/new /boot/new "$HOME/.config/new" "$tmp/outside" "$tmp/staging/../outside" "$tmp/staging/link/new"; do
  if backup_runtime_restore_target_valid "$target"; then
    echo "Unsafe restore target accepted: $target" >&2; exit 1
  fi
done
BACKUP_RESTORE_STAGING_ROOT=/
if backup_runtime_restore_target_valid "$tmp/outside"; then exit 1; fi
echo 'restore target behavior: PASS'
