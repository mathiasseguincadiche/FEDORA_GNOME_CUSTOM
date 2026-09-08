#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"

case "${1:-status}" in
  status) kernel_lifecycle_status ;;
  install-latest) kernel_lifecycle_install_latest ;;
  prune) kernel_lifecycle_prune_old ;;
  rollback) kernel_lifecycle_rollback ;;
  *)
    echo 'Usage: kernel-lifecycle.sh [status|install-latest|prune|rollback]' >&2
    exit "$EXIT_USAGE"
    ;;
esac
