#!/usr/bin/env bash
set -Eeuo pipefail

version_ge() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }

kernel_latest_available() {
  dnf -q repoquery --available --latest-limit 1 --qf '%{VERSION}-%{RELEASE}' kernel-core 2>/dev/null | sort -V | tail -n1
}

kernel_secure_boot_state() {
  local output file value
  if command_exists mokutil; then
    output="$(mokutil --sb-state 2>/dev/null || true)"
    if grep -Eqi 'SecureBoot enabled|Secure Boot enabled' <<<"$output"; then printf 'enabled\n'; return 0; fi
    if grep -Eqi 'SecureBoot disabled|Secure Boot disabled' <<<"$output"; then printf 'disabled\n'; return 0; fi
  fi
  for file in /sys/firmware/efi/efivars/SecureBoot-*; do
    [[ -r "$file" ]] || continue
    value="$(od -An -t u1 -j 4 -N 1 "$file" 2>/dev/null | tr -d '[:space:]')"
    case "$value" in 1) printf 'enabled\n'; return 0 ;; 0) printf 'disabled\n'; return 0 ;; esac
  done
  printf 'unknown\n'
}

system_kernel_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  command_exists rpm || return "$EXIT_PRECHECK_FAILED"
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  if is_true "${KERNEL_BLOCK_SECURE_BOOT:-true}"; then
    case "$(kernel_secure_boot_state)" in
      enabled)
        log_error SYSTEM 'Secure Boot is enabled; Fedora Kernel Vanilla COPR kernels require an explicit trust/signing workflow. Disable Secure Boot before APPLY or implement that workflow explicitly.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
      unknown)
        log_error SYSTEM 'Secure Boot state cannot be proven disabled. Kernel Vanilla APPLY is blocked fail-closed.'
        return "$EXIT_SECURITY_BLOCK"
        ;;
    esac
  fi
}

system_kernel_plan() {
  echo "Enable ${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}, install its latest available stable kernel (minimum ${KERNEL_MIN_VERSION:-7.2.2}), keep Fedora kernels as boot fallback and verify xe binding after reboot."
}

system_kernel_apply() {
  local -a upgrade_args=()
  is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}" || return 0
  run_mutating SYSTEM sudo dnf -y install dnf5-plugins mokutil grubby
  run_mutating SYSTEM sudo dnf -y copr enable "${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}"
  local -a names=()
  if ! is_true "${DRY_RUN:-true}"; then
    mapfile -t names < <(rpm -qa --qf '%{NAME}\n' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
  else
    names=(kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra perf python3-perf)
  fi
  if is_true "${KERNEL_VENDOR_CHANGE_ALLOWED:-true}"; then
    upgrade_args+=(--setopt=allow_vendor_change=1)
  fi
  run_mutating SYSTEM sudo dnf -y "${upgrade_args[@]}" upgrade "${names[@]}"
}

system_kernel_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local installed newest available
  installed="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' kernel-core 2>/dev/null | sort -V | tail -n1)"
  [[ -n "$installed" ]] || return "$EXIT_POSTCHECK_FAILED"
  newest="${installed%%-*}"
  if ! version_ge "$newest" "${KERNEL_MIN_VERSION:-7.2.2}"; then
    log_error SYSTEM "newest installed kernel $newest is older than required ${KERNEL_MIN_VERSION:-7.2.2}"
    return "$EXIT_POSTCHECK_FAILED"
  fi
  if is_true "${KERNEL_REQUIRE_LATEST_STABLE:-true}"; then
    available="$(kernel_latest_available)"
    [[ -n "$available" ]] || { log_error SYSTEM 'cannot resolve latest available kernel-core from enabled repositories'; return "$EXIT_POSTCHECK_FAILED"; }
    [[ "$installed" == "$available" ]] || { log_error SYSTEM "installed kernel-core $installed is not latest available $available"; return "$EXIT_POSTCHECK_FAILED"; }
  fi
  log_info SYSTEM "newest-installed-kernel=$installed current-running=$(uname -r); reboot required if they differ"
  if is_true "${KERNEL_KEEP_FEDORA_FALLBACK:-true}" && ! rpm -qa 'kernel-core-*.fc44*' 2>/dev/null | grep -q .; then
    log_warn SYSTEM 'No Fedora kernel-core fallback package detected; review before reboot'
  fi
}
