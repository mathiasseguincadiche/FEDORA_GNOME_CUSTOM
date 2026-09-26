#!/usr/bin/env bash
# Behavioral test: every module of the real catalog is sourced in isolation and
# must expose the four phase functions the orchestrator will call
# (<id with dots replaced by underscores>_{precheck,plan,apply,postcheck}).
# Before 0.16 three application modules used other names and would have failed
# with "contract missing" during the first real APPLY.
# shellcheck disable=SC2034,SC1090
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "module catalog behavior: FAIL: $*" >&2; exit 1; }

(
  REPO_ROOT="$ROOT"
  log_error() { printf '%s\n' "$*" >&2; }
  source "$ROOT/lib/constants.sh"
  source "$ROOT/lib/module_catalog.sh"
  module_catalog_load "$ROOT/manifests/module-plan.conf"
  module_catalog_validate || fail 'module-plan dependency order or paths invalid'
  (( ${#CATALOG_IDS[@]} > 50 )) || fail "catalog unexpectedly small: ${#CATALOG_IDS[@]}"
  for id in "${CATALOG_IDS[@]}"; do
    prefix="${id//./_}"
    (
      source "$ROOT/${CATALOG_PATH[$id]}" >/dev/null 2>&1 || fail "$id cannot be sourced"
      for phase in precheck plan apply postcheck; do
        declare -F "${prefix}_${phase}" >/dev/null || fail "$id does not define ${prefix}_${phase}"
      done
    )
  done
)
echo 'module catalog behavior: PASS'
