#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
password_file="$(backup_runtime_require_password)" || { echo 'Secure Restic password file is required.' >&2; exit 20; }
backup_runtime_export_env "$repo" "$password_file"
restic cat config >/dev/null || { echo 'Restic repository is not reachable.' >&2; exit 20; }

cmd="${1:-list}"
case "$cmd" in
  list)
    restic snapshots
    ;;
  verify)
    restic check --read-data-subset=1/20
    ;;
  restore)
    snapshot="${2:-latest}"
    target="${3:-${BACKUP_RESTORE_STAGING_ROOT:-$HOME/Restores/fedora-gnome-custom}/$snapshot}"
    include="${4:-}"
    target="$(readlink -m -- "$target")"
    case "$target" in
      /|/etc|/boot|/home|"$HOME"|/data|"${KVM_POOL_PATH:-/data/libvirt/images}"|"${KVM_POOL_PATH:-/data/libvirt/images}"/*)
        echo "Refusing in-place/live restore target: $target" >&2; exit 30 ;;
    esac
    if [[ -d "$target" && -n "$(find "$target" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      echo "Restore staging target must be empty: $target" >&2; exit 30
    fi
    mkdir -p "$target"
    if [[ -n "$include" ]]; then
      restic restore "$snapshot" --target "$target" --include "$include"
    else
      restic restore "$snapshot" --target "$target"
    fi
    printf 'Restored into staging only: %s\nReview content before any manual recovery.\n' "$target"
    ;;
  *)
    echo 'Usage: restore.sh [list|verify|restore SNAPSHOT [EMPTY_TARGET [INCLUDE_GLOB]]]' >&2
    exit 2
    ;;
esac
