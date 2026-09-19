#!/usr/bin/env bash
set -Eeuo pipefail
source "$REPO_ROOT/lib/performance_runtime.sh"

performance_gamemode_precheck() {
  performance_runtime_validate_policy || return "$EXIT_CONFIG_FAILED"
  [[ "$(performance_policy_get gamemode_dynamic)" == true ]] || return 0
  is_true "${GAMING_ENABLE:-false}" || return 0
  if ! is_true "${DRY_RUN:-true}"; then command_exists gamemoderun || return "$EXIT_PRECHECK_FAILED"; fi
}

performance_gamemode_plan() {
  echo 'Install a conservative GameMode policy: temporary performance governor and I/O priority while a game runs, automatic restore on exit, no GPU overclock and no persistent system-wide performance governor.'
}

performance_gamemode_apply() {
  local tmp
  [[ "$(performance_policy_get gamemode_dynamic)" == true ]] || return 0
  is_true "${GAMING_ENABLE:-false}" || return 0
  is_true "${DRY_RUN:-true}" && return 0
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF_POLICY
[general]
desiredgov=$(performance_policy_get gamemode_desired_governor)
softrealtime=off
renice=0
ioprio=0
inhibit_screensaver=1
EOF_POLICY
  run_mutating PERFORMANCE sudo install -m 0644 "$tmp" /etc/gamemode.ini || { rm -f "$tmp"; return "$EXIT_APPLY_FAILED"; }
  rm -f "$tmp"
}

performance_gamemode_postcheck() {
  [[ "$(performance_policy_get gamemode_dynamic)" == true ]] || return 0
  is_true "${GAMING_ENABLE:-false}" || return 0
  is_true "${DRY_RUN:-true}" && return 0
  [[ -r /etc/gamemode.ini ]] || return "$EXIT_POSTCHECK_FAILED"
  grep -Fxq "desiredgov=$(performance_policy_get gamemode_desired_governor)" /etc/gamemode.ini || return "$EXIT_POSTCHECK_FAILED"
  ! grep -Eqi 'gpu_device|nv_core_clock_mhz_offset|nv_mem_clock_mhz_offset|amd_performance_level' /etc/gamemode.ini || return "$EXIT_POSTCHECK_FAILED"
}
