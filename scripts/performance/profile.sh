#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/performance_runtime.sh"
performance_runtime_validate_policy || exit "$EXIT_CONFIG_FAILED"
action="${1:-status}"
case "$action" in status|balanced|performance|powersave) ;; *) echo 'Usage: profile.sh [status|balanced|performance|powersave]' >&2; exit "$EXIT_USAGE";; esac
if [[ "$action" == status ]]; then
  printf 'tuned_profile=%s\n' "$(performance_tuned_active_profile || echo unknown)"
  printf 'amd_pstate=%s\n' "$(performance_amd_pstate_status || echo unknown)"
  printf 'epp=%s\n' "$(performance_epp_values | paste -sd, - || true)"
  exit 0
fi
runtime_is_baremetal || { ui_error 'Performance profile mutation is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
profile="$(performance_profile_tuned_name "$action")"
sudo tuned-adm profile "$profile"
printf 'mode=%s\ntuned_profile=%s\nexpected_epp=%s\n' "$action" "$profile" "$(performance_profile_expected_epp "$action")"
