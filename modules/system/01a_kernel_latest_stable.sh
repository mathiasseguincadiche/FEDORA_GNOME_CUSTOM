#!/usr/bin/env bash
set -Eeuo pipefail

version_ge() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }

kernel_secure_boot_enabled() {
  command_exists mokutil || return 1
  mokutil --sb-state 2>/dev/null | grep -Eqi 'SecureBoot enabled|Secure Boot enabled'
}

kernel_current_base_version() { uname -r | sed -E 's/-.*$//'; }

system_kernel_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  command_exists rpm || return "$EXIT_PRECHECK_FAILED"
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  if is_true "${KERNEL_BLOCK_SECURE_BOOT:-true}" && kernel_secure_boot_enabled; then
    log_error SYSTEM 'Secure Boot is enabled; Fedora Kernel Vanilla COPR kernels are not expected to boot without an explicit trust/signing workflow. Disable Secure Boot before APPLY or override the kernel policy knowingly.'
    return "$EXIT_SECURITY_BLOCK"
  fi
}

system_kernel_plan() {
  echo "Enable ${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}, install the latest upstream stable kernel (minimum ${KERNEL_MIN_VERSION:-7.2.2}), keep Fedora kernels as boot fallback and verify xe binding after reboot."
}

system_kernel_apply() {
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  run_mutating SYSTEM sudo dnf -y install dnf5-plugins mokutil grubby
  run_mutating SYSTEM sudo dnf -y copr enable "${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}"
  local -a names=()
  if ! is_true "${DRY_RUN:-true}"; then
    mapfile -t names < <(rpm -qa --qf '%{NAME}\n' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
  else
    names=(kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra perf python3-perf)
  fi
  run_mutating SYSTEM sudo dnf -y --setopt=allow_vendor_change=1 upgrade "${names[@]}"
}

system_kernel_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local installed newest
  installed="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' kernel-core 2>/dev/null | sort -V | tail -n1)"
  [[ -n "$installed" ]] || return "$EXIT_POSTCHECK_FAILED"
  newest="${installed%%-*}"
  version_ge "$newest" "${KERNEL_MIN_VERSION:-7.2.2}" || {
    log_error SYSTEM "newest installed kernel $newest is older than required ${KERNEL_MIN_VERSION:-7.2.2}"
    return "$EXIT_POSTCHECK_FAILED"
  }
  log_info SYSTEM "newest-installed-kernel=$installed current-running=$(uname -r); reboot required if they differ"
  if is_true "${KERNEL_KEEP_FEDORA_FALLBACK:-true}"; then
    rpm -qa 'kernel-core-*.fc44*' 2>/dev/null | grep -q . || log_warn SYSTEM 'No Fedora kernel-core fallback package detected; review before reboot'
  fi
}
