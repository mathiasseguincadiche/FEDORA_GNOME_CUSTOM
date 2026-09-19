#!/usr/bin/env bash
set -Eeuo pipefail
source "$REPO_ROOT/lib/performance_runtime.sh"

performance_cpu_power_precheck() {
  performance_runtime_validate_policy || return "$EXIT_CONFIG_FAILED"
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
}

performance_cpu_power_plan() {
  echo 'Install Fedora-native performance tooling, keep TuneD/tuned-ppd as the GNOME power-profile bridge, and converge the normal workstation to the versioned balanced profile without BIOS/overclock/sysctl hacks.'
}

performance_cpu_power_apply() {
  install_manifest_packages PERFORMANCE "$REPO_ROOT/manifests/packages-performance.txt" || return "$EXIT_APPLY_FAILED"
  is_true "${DRY_RUN:-true}" && return 0
  if [[ "$(performance_policy_get tuned_enabled)" == true ]]; then
    run_mutating PERFORMANCE sudo systemctl enable --now tuned.service || return "$EXIT_APPLY_FAILED"
    run_mutating PERFORMANCE sudo systemctl start tuned-ppd.service || return "$EXIT_APPLY_FAILED"
    run_mutating PERFORMANCE sudo tuned-adm profile "$(performance_profile_tuned_name "$(performance_policy_get mode_default)")" || return "$EXIT_APPLY_FAILED"
  fi
}

performance_cpu_power_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/performance-doctor" --quiet --core || return "$EXIT_POSTCHECK_FAILED"
}
