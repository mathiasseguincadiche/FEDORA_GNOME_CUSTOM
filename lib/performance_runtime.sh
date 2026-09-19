#!/usr/bin/env bash
# Fedora-Cachy performance runtime helpers.
# REPO_ROOT is provided by the repository bootstrap before this file is sourced.

performance_policy_path() { printf '%s/config/performance-runtime.policy\n' "$REPO_ROOT"; }

performance_policy_get() {
  local key="$1" file value
  file="$(performance_policy_path)"
  [[ -r "$file" ]] || return 1
  value="$(awk -F= -v key="$key" '$1==key {sub(/^[^=]*=/, ""); print; exit}' "$file")"
  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}

performance_runtime_validate_policy() {
  local file line key value
  file="$(performance_policy_path)"
  [[ -r "$file" ]] || { ui_error "Missing performance policy: $file"; return "$EXIT_CONFIG_FAILED"; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ ^([a-z][a-z0-9_]*)=([A-Za-z0-9._-]+)$ ]] || {
      ui_error "Unsafe performance policy line: $line"
      return "$EXIT_CONFIG_FAILED"
    }
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    case "$key" in
      schema) [[ "$value" == 1 ]] || return "$EXIT_CONFIG_FAILED" ;;
      mode_default) [[ "$value" =~ ^(balanced|performance|powersave)$ ]] || return "$EXIT_CONFIG_FAILED" ;;
      tuned_enabled|require_amd_pstate|sched_ext_enable_by_default|allow_experimental_io_scheduler|gamemode_dynamic|frametime_log_required)
        [[ "$value" =~ ^(true|false)$ ]] || return "$EXIT_CONFIG_FAILED"
        ;;
      tuned_balanced_profile|tuned_performance_profile|tuned_powersave_profile|amd_pstate_mode|epp_balanced|epp_performance|epp_powersave|gamemode_desired_governor)
        :
        ;;
      sched_ext_policy) [[ "$value" =~ ^(off|auto|required)$ ]] || return "$EXIT_CONFIG_FAILED" ;;
      sched_ext_smoke_seconds) [[ "$value" =~ ^[1-9][0-9]*$ ]] || return "$EXIT_CONFIG_FAILED" ;;
      zram_policy) [[ "$value" == fedora-default ]] || return "$EXIT_CONFIG_FAILED" ;;
      nvme_policy) [[ "$value" == benchmark-only ]] || return "$EXIT_CONFIG_FAILED" ;;
      *) ui_error "Unknown performance policy key: $key"; return "$EXIT_CONFIG_FAILED" ;;
    esac
  done < "$file"

  [[ "$(performance_policy_get amd_pstate_mode)" =~ ^(active|passive|guided)$ ]] || return "$EXIT_CONFIG_FAILED"
  [[ "$(performance_policy_get epp_balanced)" =~ ^(balance_performance|balance_power|performance|power)$ ]] || return "$EXIT_CONFIG_FAILED"
  [[ "$(performance_policy_get epp_performance)" =~ ^(balance_performance|performance)$ ]] || return "$EXIT_CONFIG_FAILED"
  [[ "$(performance_policy_get epp_powersave)" =~ ^(balance_power|power)$ ]] || return "$EXIT_CONFIG_FAILED"
}

performance_profile_tuned_name() {
  case "$1" in
    balanced) performance_policy_get tuned_balanced_profile ;;
    performance) performance_policy_get tuned_performance_profile ;;
    powersave) performance_policy_get tuned_powersave_profile ;;
    *) return 1 ;;
  esac
}

performance_profile_expected_epp() {
  case "$1" in
    balanced) performance_policy_get epp_balanced ;;
    performance) performance_policy_get epp_performance ;;
    powersave) performance_policy_get epp_powersave ;;
    *) return 1 ;;
  esac
}

performance_cpu_scaling_driver() {
  cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver 2>/dev/null
}

performance_amd_pstate_status() {
  cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null
}

performance_cpu_boost() {
  if [[ -r /sys/devices/system/cpu/cpufreq/boost ]]; then
    cat /sys/devices/system/cpu/cpufreq/boost
  elif [[ -r /sys/devices/system/cpu/cpu0/cpufreq/boost ]]; then
    cat /sys/devices/system/cpu/cpu0/cpufreq/boost
  fi
}

performance_epp_values() {
  local file
  for file in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    [[ -r "$file" ]] || continue
    cat "$file"
  done | sort -u
}

performance_tuned_active_profile() {
  command -v tuned-adm >/dev/null 2>&1 || return 1
  tuned-adm active 2>/dev/null | sed -nE 's/^[Cc]urrent active profile:[[:space:]]*//p' | head -n1
}

performance_mode_from_tuned_profile() {
  local active="$1" mode expected
  for mode in balanced performance powersave; do
    expected="$(performance_profile_tuned_name "$mode")" || continue
    [[ "$active" == "$expected" ]] && { printf '%s\n' "$mode"; return 0; }
  done
  return 1
}
