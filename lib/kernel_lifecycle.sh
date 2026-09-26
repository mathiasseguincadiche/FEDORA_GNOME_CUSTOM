#!/usr/bin/env bash
# Rolling kernel N / N-1 lifecycle helpers.
# Two channels are supported (ADR 0012):
#   vanilla  -> @kernel-vanilla/stable, packages kernel/kernel-core/...
#   cachyos  -> bieszczaders/kernel-cachyos (BORE), packages kernel-cachyos/...
# The managed channel is selected by KERNEL_CHANNEL. With the cachyos channel,
# the kernel-core track (Fedora or Kernel Vanilla) stays installed as rescue.
# REPO_ROOT, STATE_ROOT and project configuration are loaded by engine_bootstrap.

kernel_lifecycle_state_dir() { printf '%s/kernel' "$STATE_ROOT"; }
kernel_lifecycle_state_path() { printf '%s/rolling.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_policy_path() { printf '%s/config/kernel-lifecycle.policy' "$REPO_ROOT"; }
kernel_lifecycle_ensure_dir() { mkdir -p "$(kernel_lifecycle_state_dir)"; }

kernel_lifecycle_value() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

# --- Channel abstraction ---------------------------------------------------

kernel_channel() {
  local channel="${KERNEL_CHANNEL:-vanilla}"
  case "$channel" in
    vanilla|cachyos) printf '%s\n' "$channel" ;;
    *) return 1 ;;
  esac
}

kernel_channel_label() {
  case "$(kernel_channel)" in
    vanilla) printf 'Kernel Vanilla stable\n' ;;
    cachyos) printf 'CachyOS (BORE)\n' ;;
    *) return 1 ;;
  esac
}

kernel_channel_copr() {
  case "$(kernel_channel)" in
    vanilla) printf '%s\n' "${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}" ;;
    cachyos) printf '%s\n' "${KERNEL_CACHYOS_COPR:-bieszczaders/kernel-cachyos}" ;;
    *) return 1 ;;
  esac
}

# Extended regex matched against `dnf5 repo list` ids. The cachyos pattern is
# anchored so that -addons, -lto, -lts and -rc COPRs never match.
kernel_channel_repo_pattern() {
  case "$(kernel_channel)" in
    vanilla) printf '%s\n' 'kernel[-_]vanilla.*stable|group_kernel-vanilla:stable' ;;
    cachyos) printf '%s\n' '(^|:)bieszczaders:kernel-cachyos$' ;;
    *) return 1 ;;
  esac
}

kernel_channel_core_package() {
  case "$(kernel_channel)" in
    vanilla) printf 'kernel-core\n' ;;
    cachyos) printf 'kernel-cachyos-core\n' ;;
    *) return 1 ;;
  esac
}

kernel_channel_release_marker() {
  case "$(kernel_channel)" in
    vanilla) printf 'vanilla\n' ;;
    cachyos) printf 'cachyos\n' ;;
    *) return 1 ;;
  esac
}

kernel_channel_packages() {
  case "$(kernel_channel)" in
    vanilla) printf '%s\n' kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra ;;
    cachyos) printf '%s\n' kernel-cachyos kernel-cachyos-core kernel-cachyos-modules ;;
    *) return 1 ;;
  esac
}

kernel_channel_optional_packages() {
  case "$(kernel_channel)" in
    vanilla) printf '%s\n' perf python3-perf ;;
    cachyos) is_true "${KERNEL_CACHYOS_INSTALL_DEVEL:-false}" && printf '%s\n' kernel-cachyos-devel-matched ;;
  esac
  return 0
}

kernel_channel_release_matches() {
  local release="$1" marker
  marker="$(kernel_channel_release_marker)" || return 1
  [[ -n "$release" && "$release" == *"$marker"* ]]
}

# Wrapper so tests can replace the dynamic loader probe.
kernel_lifecycle_ldso_help() {
  local ldso="${KERNEL_LDSO_PATH:-/lib64/ld-linux-x86-64.so.2}"
  [[ -x "$ldso" ]] || return 1
  "$ldso" --help 2>/dev/null
}

kernel_lifecycle_cpu_supports_x86_64_v3() {
  # Capture first: `producer | grep -q` can fail under pipefail (SIGPIPE).
  local help
  help="$(kernel_lifecycle_ldso_help)" || return 1
  grep -Eq 'x86-64-v3[[:space:]]+\(supported, searched\)' <<<"$help"
}

kernel_lifecycle_selinux_module_boolean() {
  command_exists getsebool || { printf 'unavailable\n'; return 0; }
  getsebool domain_kernel_load_modules 2>/dev/null | awk '{print $NF; exit}'
}

# Channel-specific platform requirements, checked before any mutation.
kernel_channel_require_platform() {
  kernel_channel >/dev/null || { ui_error "Unsupported KERNEL_CHANNEL=${KERNEL_CHANNEL:-}; expected vanilla or cachyos"; return "$EXIT_CONFIG_FAILED"; }
  [[ "$(kernel_channel)" == cachyos ]] || return 0
  kernel_lifecycle_cpu_supports_x86_64_v3 || {
    ui_error 'CPU does not report x86-64-v3 support; kernel-cachyos would not boot. Use KERNEL_CHANNEL="vanilla".'
    return "$EXIT_SECURITY_BLOCK"
  }
  is_true "${KERNEL_CACHYOS_SELINUX_MODULE_LOAD:-false}" || {
    ui_error 'kernel-cachyos requires the SELinux boolean domain_kernel_load_modules=on; accept it explicitly with KERNEL_CACHYOS_SELINUX_MODULE_LOAD="true" (see ADR 0012).'
    return "$EXIT_CONFIG_FAILED"
  }
}

kernel_lifecycle_policy_value() { kernel_lifecycle_value "$(kernel_lifecycle_policy_path)" "$1"; }

kernel_lifecycle_max_installed() {
  local value
  value="$(kernel_lifecycle_policy_value max_installed_kernels 2>/dev/null || true)"
  [[ "$value" =~ ^[2-9][0-9]*$ ]] || value=2
  printf '%s\n' "$value"
}

kernel_lifecycle_release_is_stable() {
  local release="${1,,}"
  [[ -n "$release" ]] || return 1
  [[ "$release" != *linux-next* && "$release" != *mainline* && ! "$release" =~ (^|[-._])rc[0-9]*($|[-._]) ]]
}

kernel_lifecycle_version_at_least() {
  local release="$1" version minimum="${KERNEL_MIN_VERSION:-7.2.2}" first
  version="${release%%-*}"
  [[ "$version" =~ ^[0-9]+([.][0-9]+){1,3}$ && "$minimum" =~ ^[0-9]+([.][0-9]+){1,3}$ ]] || return 1
  first="$(printf '%s\n%s\n' "$minimum" "$version" | sort -V | head -n1)"
  [[ "$first" == "$minimum" ]]
}

kernel_lifecycle_channel_repo_id() {
  local pattern
  local -a repos=()
  command_exists dnf5 || return 1
  pattern="$(kernel_channel_repo_pattern)" || return 1
  mapfile -t repos < <(
    dnf5 -q repo list --enabled 2>/dev/null \
      | awk 'NR>1 {print $1}' \
      | grep -Ei -- "$pattern" \
      | sort -u
  )
  (( ${#repos[@]} == 1 )) || return 1
  printf '%s\n' "${repos[0]}"
}

# Backward-compatible name used by older call sites and documentation.
kernel_lifecycle_vanilla_repo_id() { KERNEL_CHANNEL=vanilla kernel_lifecycle_channel_repo_id; }

kernel_lifecycle_latest_available() {
  local repo core marker
  repo="$(kernel_lifecycle_channel_repo_id)" || return 1
  core="$(kernel_channel_core_package)" || return 1
  marker="$(kernel_channel_release_marker)" || return 1
  dnf5 -q --repo="$repo" repoquery --available --latest-limit 1 \
    --qf $'%{VERSION}-%{RELEASE}.%{ARCH}\n' "$core" 2>/dev/null \
    | grep -F -- "$marker" \
    | sort -V \
    | tail -n1
}

kernel_lifecycle_latest_nevras() {
  local release="$1" repo pkg found vr
  local -a required=() optional=()
  repo="$(kernel_lifecycle_channel_repo_id)" || return 1
  mapfile -t required < <(kernel_channel_packages)
  mapfile -t optional < <(kernel_channel_optional_packages)
  vr="${release%.*}"
  for pkg in "${required[@]}"; do
    found="$(dnf5 -q --repo="$repo" repoquery --available --qf $'%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$pkg" 2>/dev/null \
      | grep -Fx "$pkg-$release" | head -n1)"
    [[ -n "$found" ]] || { ui_error "Exact $(kernel_channel_label) NEVRA missing for $pkg release=$release repo=$repo"; return 1; }
    printf '%s\n' "$found"
  done
  for pkg in "${optional[@]}"; do
    dnf5 -q --repo="$repo" repoquery --available --qf $'%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$pkg" 2>/dev/null \
      | grep -F -- "-$vr." | sort -V | tail -n1 || true
  done
}

kernel_lifecycle_expected_nevra_count() {
  kernel_channel_packages | wc -l | tr -d '[:space:]'
}

kernel_lifecycle_installed_releases() {
  # Always succeeds: an empty result means "no kernel of this channel installed".
  local core output
  core="$(kernel_channel_core_package)" || return 1
  output="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' "$core" 2>/dev/null || true)"
  printf '%s\n' "$output" \
    | grep -v -e 'is not installed' -e '^[[:space:]]*$' \
    | sort -Vu \
    || true
}

kernel_lifecycle_installed_count() {
  local -a releases=()
  mapfile -t releases < <(kernel_lifecycle_installed_releases)
  printf '%s\n' "${#releases[@]}"
}

kernel_lifecycle_latest_installed() {
  kernel_lifecycle_installed_releases | tail -n1
}

kernel_lifecycle_previous_installed() {
  local -a releases=()
  mapfile -t releases < <(kernel_lifecycle_installed_releases)
  (( ${#releases[@]} >= 2 )) || return 0
  printf '%s\n' "${releases[${#releases[@]}-2]}"
}

kernel_lifecycle_release_installed() {
  local release="$1"
  kernel_lifecycle_installed_releases | grep -Fxq "$release"
}

kernel_lifecycle_default_release() {
  local kernel
  kernel="$(grubby --default-kernel 2>/dev/null || true)"
  kernel="${kernel##*/vmlinuz-}"
  printf '%s\n' "${kernel:-unknown}"
}

kernel_lifecycle_secure_boot_state() {
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

kernel_lifecycle_require_host_gate() {
  runtime_is_baremetal || { ui_error 'Kernel mutations are bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  case "$(kernel_lifecycle_secure_boot_state)" in
    disabled) ;;
    enabled) ui_error "Secure Boot is enabled; $(kernel_channel_label) is blocked by Golden HOST policy"; return "$EXIT_SECURITY_BLOCK" ;;
    *) ui_error "Secure Boot state is unknown; $(kernel_channel_label) mutation is blocked fail-closed"; return "$EXIT_SECURITY_BLOCK" ;;
  esac
  kernel_channel_require_platform || return $?
}

kernel_lifecycle_require_install_gate() {
  kernel_lifecycle_require_host_gate || return $?
  apply_gate_require_clean_git || { ui_error 'Kernel installation requires a clean Git worktree'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_baseline || { ui_error "Valid hardware baseline required before $(kernel_channel_label) installation"; return "$EXIT_PRECHECK_FAILED"; }
  apply_gate_require_backup || { ui_error "Fresh current-identity pre-APPLY backup required before $(kernel_channel_label) installation"; return "$EXIT_PRECHECK_FAILED"; }
}

kernel_lifecycle_dnf_limit() {
  dnf5 --dump-main-config 2>/dev/null \
    | awk -F= '$1 ~ /^[[:space:]]*installonly_limit[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2; exit}'
}

kernel_lifecycle_ensure_tooling_and_repo() {
  local copr
  command_exists dnf5 || { ui_error "dnf5 is required for $(kernel_channel_label) management"; return "$EXIT_PRECHECK_FAILED"; }
  copr="$(kernel_channel_copr)" || { ui_error "Unsupported KERNEL_CHANNEL=${KERNEL_CHANNEL:-}"; return "$EXIT_CONFIG_FAILED"; }
  sudo dnf5 -y install dnf5-plugins mokutil grubby grub2-tools-minimal
  sudo dnf5 -y copr enable "$copr"
  kernel_lifecycle_channel_repo_id >/dev/null || { ui_error "Unable to identify exactly one enabled $(kernel_channel_label) repository"; return "$EXIT_POSTCHECK_FAILED"; }
  if [[ "$(kernel_channel)" == cachyos ]]; then
    # Documented upstream requirement for kernel-cachyos on SELinux hosts (ADR 0012).
    if [[ "$(kernel_lifecycle_selinux_module_boolean)" != on ]]; then
      sudo setsebool -P domain_kernel_load_modules on
    fi
    [[ "$(kernel_lifecycle_selinux_module_boolean)" == on ]] || { ui_error 'SELinux boolean domain_kernel_load_modules is not on'; return "$EXIT_POSTCHECK_FAILED"; }
  fi
}

kernel_lifecycle_ensure_dnf_retention() {
  local limit current
  limit="$(kernel_lifecycle_max_installed)"
  (( limit == 2 )) || { ui_error "Golden N/N-1 policy requires max_installed_kernels=2, got $limit"; return "$EXIT_CONFIG_FAILED"; }
  sudo dnf5 config-manager setopt "installonly_limit=$limit"
  current="$(kernel_lifecycle_dnf_limit)"
  [[ "$current" == "$limit" ]] || { ui_error "DNF installonly_limit mismatch: expected=$limit actual=${current:-unknown}"; return "$EXIT_POSTCHECK_FAILED"; }
  ui_check OK 'Kernel retention' "DNF installonly_limit=$limit"
}

kernel_lifecycle_resolve_latest_stable() {
  local available
  available="$(kernel_lifecycle_latest_available)"
  [[ -n "$available" ]] || { ui_error "Unable to resolve latest available $(kernel_channel_label)"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_release_is_stable "$available" || { ui_error "Refusing non-stable kernel: $available"; return "$EXIT_SECURITY_BLOCK"; }
  kernel_lifecycle_version_at_least "$available" || { ui_error "Kernel $available is below minimum ${KERNEL_MIN_VERSION:-7.2.2}"; return "$EXIT_SECURITY_BLOCK"; }
  kernel_channel_release_matches "$available" || { ui_error "Resolved kernel is not a $(kernel_channel_label) build: $available"; return "$EXIT_SECURITY_BLOCK"; }
  printf '%s\n' "$available"
}

kernel_lifecycle_prepare_rolling_update() {
  kernel_lifecycle_require_host_gate || return $?
  kernel_lifecycle_ensure_tooling_and_repo || return $?
  kernel_lifecycle_ensure_dnf_retention || return $?
  kernel_lifecycle_resolve_latest_stable
}

kernel_lifecycle_prune_old() {
  local limit count
  limit="$(kernel_lifecycle_max_installed)"
  sudo dnf5 -y remove --oldinstallonly --limit="$limit"
  count="$(kernel_lifecycle_installed_count)"
  (( count <= limit )) || {
    ui_error "Kernel retention still exceeds policy after prune: installed=$count max=$limit. Boot the newest kernel and retry."
    return "$EXIT_POSTCHECK_FAILED"
  }
  ui_check OK 'Kernel retention' "$count $(kernel_channel_core_package) version(s) installed; max=$limit"
}

kernel_lifecycle_set_latest_default() {
  local latest
  latest="$(kernel_lifecycle_latest_installed)"
  [[ -n "$latest" && -e "/boot/vmlinuz-$latest" ]] || { ui_error 'Latest installed kernel boot image is missing'; return "$EXIT_POSTCHECK_FAILED"; }
  sudo grubby --set-default "/boot/vmlinuz-$latest"
  [[ "$(kernel_lifecycle_default_release)" == "$latest" ]] || { ui_error "GRUB default does not match latest installed kernel $latest"; return "$EXIT_POSTCHECK_FAILED"; }
  ui_check OK 'GRUB default' "$latest"
}

kernel_lifecycle_write_state() {
  local source="${1:-runtime}" latest previous default count
  kernel_lifecycle_ensure_dir
  latest="$(kernel_lifecycle_latest_installed)"
  previous="$(kernel_lifecycle_previous_installed)"
  default="$(kernel_lifecycle_default_release)"
  count="$(kernel_lifecycle_installed_count)"
  {
    printf 'schema=2\n'
    printf 'mode=rolling-n-nminus1\n'
    printf 'channel=%s\n' "$(kernel_channel 2>/dev/null || echo invalid)"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'project_commit=%s\n' "$(repo_commit)"
    printf 'effective_config_sha256=%s\n' "$(effective_config_sha256)"
    printf 'source=%s\n' "$source"
    printf 'running=%s\n' "$(uname -r)"
    printf 'latest_installed=%s\n' "${latest:-none}"
    printf 'previous_installed=%s\n' "${previous:-none}"
    printf 'default=%s\n' "${default:-unknown}"
    printf 'installed_count=%s\n' "$count"
    printf 'max_installed=%s\n' "$(kernel_lifecycle_max_installed)"
  } | evidence_atomic_write "$(kernel_lifecycle_state_path)" 0600
}

kernel_lifecycle_install_latest() {
  kernel_lifecycle_require_install_gate || return $?
  kernel_lifecycle_ensure_tooling_and_repo || return $?
  kernel_lifecycle_ensure_dnf_retention || return $?

  local available installed
  local -a exact_nevras=() install_args=()
  available="$(kernel_lifecycle_resolve_latest_stable)" || return $?
  mapfile -t exact_nevras < <(kernel_lifecycle_latest_nevras "$available")
  (( ${#exact_nevras[@]} >= $(kernel_lifecycle_expected_nevra_count) )) || { ui_error "Incomplete exact $(kernel_channel_label) NEVRA set"; return "$EXIT_POSTCHECK_FAILED"; }
  is_true "${KERNEL_VENDOR_CHANGE_ALLOWED:-true}" && install_args+=(--setopt=allow_vendor_change=1)
  sudo dnf5 -y "${install_args[@]}" install "${exact_nevras[@]}"

  installed="$(kernel_lifecycle_latest_installed)"
  [[ "$installed" == "$available" ]] || { ui_error "Kernel install mismatch: installed=${installed:-missing} available=$available"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_set_latest_default || return $?
  kernel_lifecycle_prune_old || return $?
  kernel_lifecycle_write_state initial-install
  ui_check OK "$(kernel_channel_label) rolling" "$installed installed directly; previous kernel retained as N-1"
}

kernel_lifecycle_finalize_update() {
  local target="$1" latest running
  [[ -n "$target" && "$target" != none ]] || return 0
  kernel_lifecycle_require_host_gate || return $?
  kernel_lifecycle_ensure_dnf_retention || return $?
  kernel_lifecycle_release_installed "$target" || { ui_error "Expected updated kernel is not installed: $target"; return "$EXIT_POSTCHECK_FAILED"; }

  latest="$(kernel_lifecycle_latest_installed)"
  [[ "$latest" == "$target" ]] || { ui_error "Latest installed kernel mismatch: expected=$target actual=${latest:-missing}"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_set_latest_default || return $?

  running="$(uname -r)"
  if [[ "$running" != "$target" ]]; then
    ui_error "Updated kernel $target is installed and set as GRUB default, but running=$running. Reboot once into $target, then rerun ./control.sh update finalize."
    return "$EXIT_PRECHECK_FAILED"
  fi

  kernel_lifecycle_prune_old || return $?
  kernel_lifecycle_write_state system-update
  ui_check OK 'Kernel N/N-1' "running N=$target; rollback N-1=$(kernel_lifecycle_previous_installed)"
}

kernel_lifecycle_rollback() {
  kernel_lifecycle_require_host_gate || return $?
  command_exists grubby || { ui_error 'grubby is required for kernel rollback'; return "$EXIT_PRECHECK_FAILED"; }
  local previous latest
  latest="$(kernel_lifecycle_latest_installed)"
  previous="$(kernel_lifecycle_previous_installed)"
  [[ -n "$previous" && "$previous" != "$latest" ]] || { ui_error 'No N-1 kernel is installed for rollback'; return "$EXIT_PRECHECK_FAILED"; }
  [[ -e "/boot/vmlinuz-$previous" ]] || { ui_error "Boot image missing for N-1 kernel: $previous"; return "$EXIT_POSTCHECK_FAILED"; }
  sudo grubby --set-default "/boot/vmlinuz-$previous"
  [[ "$(kernel_lifecycle_default_release)" == "$previous" ]] || { ui_error "Unable to set N-1 kernel as GRUB default: $previous"; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_write_state rollback-selected
  ui_check OK 'Kernel rollback' "N-1=$previous is now GRUB default; N=$latest remains installed"
}

kernel_lifecycle_status() {
  local running latest previous available default count limit dnf_limit
  running="$(uname -r)"
  latest="$(kernel_lifecycle_latest_installed)"
  previous="$(kernel_lifecycle_previous_installed)"
  available="$(kernel_lifecycle_latest_available 2>/dev/null || true)"
  default="$(kernel_lifecycle_default_release)"
  count="$(kernel_lifecycle_installed_count)"
  limit="$(kernel_lifecycle_max_installed)"
  dnf_limit="$(kernel_lifecycle_dnf_limit 2>/dev/null || true)"
  printf 'mode=rolling-n-nminus1\n'
  printf 'channel=%s\n' "$(kernel_channel 2>/dev/null || echo invalid)"
  printf 'running=%s\n' "$running"
  printf 'latest_installed=%s\n' "${latest:-none}"
  printf 'previous_installed=%s\n' "${previous:-none}"
  printf 'grub_default=%s\n' "${default:-unknown}"
  printf 'latest_available=%s\n' "${available:-unresolved}"
  printf 'installed_count=%s\n' "$count"
  printf 'max_installed=%s\n' "$limit"
  printf 'dnf_installonly_limit=%s\n' "${dnf_limit:-unknown}"
}
