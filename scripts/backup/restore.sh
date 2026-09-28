#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

backup_engine_require || exit 20
repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
backup_engine_env "$repo"
backup_engine_repo_ready || { echo 'Borg repository is not reachable (or is encrypted).' >&2; exit 20; }

cmd="${1:-list}"
case "$cmd" in
  list)
    borg list --format '{archive:<48} {time} {id}{NL}'
    ;;
  verify)
    borg check --verify-data
    ;;
  restore)
    archive="${2:-latest}"
    if [[ "$archive" == latest ]]; then
      read -r archive _ < <(backup_engine_latest) || { echo 'No archive in the repository.' >&2; exit 30; }
    fi
    [[ "$archive" =~ ^fgc-(preapply|full|daily)-[0-9TZ.]+$ ]] || { echo "Unknown archive name: $archive (see: restore.sh list)" >&2; exit 30; }
    target="${3:-${BACKUP_RESTORE_STAGING_ROOT:-$HOME/Restores/fedora-gnome-custom}/$archive}"
    include="${4:-}"
    target="$(readlink -m -- "$target")"
    backup_runtime_restore_target_valid "$target" || {
      echo "Restore target must stay inside the configured staging root: $target" >&2; exit 30
    }
    case "$target" in
      /|/etc|/boot|/home|"$HOME"|/data|"${KVM_POOL_PATH:-/data/libvirt/images}"|"${KVM_POOL_PATH:-/data/libvirt/images}"/*)
        echo "Refusing in-place/live restore target: $target" >&2; exit 30 ;;
    esac
    if [[ -d "$target" && -n "$(find "$target" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      echo "Restore staging target must be empty: $target" >&2; exit 30
    fi
    mkdir -p "$target"
    # Borg verifies every chunk against its hash while extracting.
    if [[ -n "$include" ]]; then
      backup_engine_extract "$archive" "$target" "$include"
    else
      backup_engine_extract "$archive" "$target"
    fi
    printf 'Restored into staging only: %s\nReview content before any manual recovery.\n' "$target"
    ;;
  *)
    echo 'Usage: restore.sh [list|verify|restore ARCHIVE|latest [EMPTY_TARGET [ABSOLUTE_PATH]]]' >&2
    exit 2
    ;;
esac
