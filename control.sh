#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

# Kernel lifecycle commands are routed directly to the dedicated engine so the
# operator CLI can expose candidate -> certify without duplicating business logic.
if [[ "${1:-}" == kernel ]]; then
  case "${2:-}" in
    candidate|boot-candidate|certify|rollback)
      exec bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" "$2"
      ;;
    rollback-fedora)
      exec bash "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
      ;;
  esac
fi

# shellcheck source=lib/control_center.sh
source "$REPO_ROOT/lib/control_center.sh"
control_center_main "$@"
