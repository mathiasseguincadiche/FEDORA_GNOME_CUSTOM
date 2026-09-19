#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/performance_runtime.sh"
(($# > 0)) || { echo 'Usage: game-performance.sh COMMAND [ARG ...]' >&2; exit "$EXIT_USAGE"; }
runtime_is_baremetal || { ui_error 'Dynamic gaming profile is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
command -v gamemoderun >/dev/null 2>&1 || { ui_error 'gamemoderun is required'; exit "$EXIT_PRECHECK_FAILED"; }
previous="$(performance_tuned_active_profile || true)"
restore(){ if [[ -n "$previous" ]]; then sudo tuned-adm profile "$previous" >/dev/null 2>&1 || true; fi; }
trap restore EXIT INT TERM
sudo tuned-adm profile "$(performance_profile_tuned_name performance)"
gamemoderun "$@"
