#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/kernel_lifecycle.sh"

system_kernel_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  command_exists rpm || return "$EXIT_PRECHECK_FAILED"
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  if is_true "${KERNEL_BLOCK_SECURE_BOOT:-true}"; then
    case "$(kernel_lifecycle_secure_boot_state)" in
      enabled)
        log_error SYSTEM 'Secure Boot is enabled; Fedora Kernel Vanilla candidate staging is blocked until an explicit trust/signing workflow exists.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
      unknown)
        log_error SYSTEM 'Secure Boot state cannot be proven disabled. Kernel Vanilla candidate staging is blocked fail-closed.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
    esac
  fi
}

system_kernel_plan() {
  echo "Stage the latest stable kernel from ${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable} as a non-certified candidate (minimum ${KERNEL_MIN_VERSION:-7.2.2}), preserve the current certified/Fedora boot default, then require bare-metal qualification before promotion."
}

system_kernel_apply() {
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  run_mutating SYSTEM bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" candidate
}

system_kernel_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  local candidate certified
  candidate="$(kernel_lifecycle_candidate_release)"
  certified="$(kernel_lifecycle_certified_release)"
  [[ -n "$candidate" ]] || { log_error SYSTEM 'Kernel Vanilla candidate marker missing after APPLY'; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_release_installed "$candidate" || { log_error SYSTEM "Kernel candidate is not installed: $candidate"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_release_is_stable "$candidate" || { log_error SYSTEM "Kernel candidate is not stable: $candidate"; return "$EXIT_POSTCHECK_FAILED"; }
  [[ "$candidate" == *vanilla* ]] || { log_error SYSTEM "Kernel candidate is not a Kernel Vanilla build: $candidate"; return "$EXIT_POSTCHECK_FAILED"; }
  log_info SYSTEM "candidate=$candidate certified=${certified:-none} running=$(uname -r); candidate is not Golden until explicit certification"
  if is_true "${KERNEL_KEEP_FEDORA_FALLBACK:-true}" && ! rpm -qa 'kernel-core-*.fc44*' 2>/dev/null | grep -q .; then
    log_warn SYSTEM 'No Fedora kernel-core fallback package detected; review before reboot'
  fi
}
