#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/kernel_lifecycle.sh"

system_kernel_precheck() {
  command_exists dnf5 || return "$EXIT_PRECHECK_FAILED"
  command_exists rpm || return "$EXIT_PRECHECK_FAILED"
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  if is_true "${KERNEL_BLOCK_SECURE_BOOT:-true}"; then
    case "$(kernel_lifecycle_secure_boot_state)" in
      enabled)
        log_error SYSTEM 'Secure Boot is enabled; Fedora Kernel Vanilla installation is blocked until an explicit trust/signing workflow exists.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
      unknown)
        log_error SYSTEM 'Secure Boot state cannot be proven disabled. Kernel Vanilla installation is blocked fail-closed.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
    esac
  fi
}

system_kernel_plan() {
  echo "Install the latest stable kernel from ${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable} directly (minimum ${KERNEL_MIN_VERSION:-7.2.2}), set it as GRUB default, retain only N/N-1, and disable Fedora's separate rescue boot entry."
}

system_kernel_apply() {
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  run_mutating SYSTEM bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" install-latest
  run_mutating SYSTEM bash "$REPO_ROOT/scripts/kernel/enforce-two-entry-grub.sh" --apply
}

system_kernel_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  local latest previous count limit default
  latest="$(kernel_lifecycle_latest_installed)"
  previous="$(kernel_lifecycle_previous_installed)"
  count="$(kernel_lifecycle_installed_count)"
  limit="$(kernel_lifecycle_max_installed)"
  default="$(kernel_lifecycle_default_release)"
  [[ -n "$latest" ]] || { log_error SYSTEM 'No installed kernel-core found after Kernel Vanilla APPLY'; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_release_is_stable "$latest" || { log_error SYSTEM "Latest installed kernel is not stable: $latest"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_version_at_least "$latest" || { log_error SYSTEM "Latest installed kernel is below ${KERNEL_MIN_VERSION:-7.2.2}: $latest"; return "$EXIT_POSTCHECK_FAILED"; }
  [[ "$latest" == *vanilla* ]] || { log_error SYSTEM "Latest installed kernel is not a Kernel Vanilla build: $latest"; return "$EXIT_POSTCHECK_FAILED"; }
  (( count <= limit && limit == 2 )) || { log_error SYSTEM "Kernel retention mismatch: installed=$count max=$limit"; return "$EXIT_POSTCHECK_FAILED"; }
  [[ "$default" == "$latest" ]] || { log_error SYSTEM "GRUB default mismatch: default=$default latest=$latest"; return "$EXIT_POSTCHECK_FAILED"; }
  bash "$REPO_ROOT/scripts/kernel/enforce-two-entry-grub.sh" --check >/dev/null || { log_error SYSTEM 'GRUB contains a rescue/extra kernel entry outside N/N-1 policy'; return "$EXIT_POSTCHECK_FAILED"; }
  log_info SYSTEM "N=$latest N-1=${previous:-none} installed=$count max=$limit; rescue entry disabled; latest stable is the persistent GRUB default"
}
