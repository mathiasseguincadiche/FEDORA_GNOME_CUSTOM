#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"

case "${1:-status}" in
  status) kernel_lifecycle_status ;;
  candidate) kernel_lifecycle_stage_candidate ;;
  boot-candidate) kernel_lifecycle_schedule_candidate_once ;;
  certify) kernel_lifecycle_certify_candidate ;;
  rollback) kernel_lifecycle_rollback ;;
  *)
    echo 'Usage: kernel-lifecycle.sh [status|candidate|boot-candidate|certify|rollback]' >&2
    exit "$EXIT_USAGE"
    ;;
esac
