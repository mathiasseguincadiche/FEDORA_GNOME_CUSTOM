#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"

mode="${1:---apply}"
case "$mode" in
  --apply|--check) ;;
  *) echo 'Usage: enforce-two-entry-grub.sh [--apply|--check]' >&2; exit "$EXIT_USAGE" ;;
esac

runtime_is_baremetal || { ui_error 'GRUB kernel-retention enforcement is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
kernel_lifecycle_enforce_grub_surface "$mode"
