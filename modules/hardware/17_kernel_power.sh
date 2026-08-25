#!/usr/bin/env bash
set -Eeuo pipefail
hardware_kernel_power_precheck() { command_exists rpm && command_exists uname; }
hardware_kernel_power_plan() { echo 'Keep the Fedora kernel, reject known destabilizing kernel arguments, validate taint/microcode/AMD P-State and preserve balanced power policy without global ASPM/C-state hacks.'; }
hardware_kernel_power_apply() { install_manifest_packages HARDWARE "$REPO_ROOT/manifests/packages-hardware.txt"; }
hardware_kernel_power_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local release cmdline taint
  release="$(uname -r)"; cmdline="$(< /proc/cmdline)"; taint="$(< /proc/sys/kernel/tainted)"
  if is_true "${KERNEL_REQUIRE_FEDORA_BUILD:-true}"; then [[ "$release" == *"${KERNEL_EXPECT_RELEASE_TOKEN:-fc44}"* ]] || return "$EXIT_POSTCHECK_FAILED"; fi
  if [[ -n "${KERNEL_FORBIDDEN_CMDLINE_REGEX:-}" ]] && grep -Eqi -- "$KERNEL_FORBIDDEN_CMDLINE_REGEX" <<< "$cmdline"; then return "$EXIT_POSTCHECK_FAILED"; fi
  if is_true "${KERNEL_REQUIRE_UNTAINTED:-true}"; then [[ "$taint" == 0 ]] || return "$EXIT_POSTCHECK_FAILED"; fi
  if [[ -r /sys/devices/system/cpu/amd_pstate/status ]]; then log_info HARDWARE "amd_pstate=$(< /sys/devices/system/cpu/amd_pstate/status)"; else log_warn HARDWARE 'AMD P-State status is not exposed'; fi
  if command_exists powerprofilesctl; then log_info HARDWARE "power-profile=$(powerprofilesctl get 2>/dev/null || echo unavailable)"; fi
}
