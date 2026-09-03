#!/usr/bin/env bash
# Kernel candidate -> certified lifecycle helpers.
# REPO_ROOT, STATE_ROOT and project configuration are loaded by engine_bootstrap.

kernel_lifecycle_state_dir() { printf '%s/kernel' "$STATE_ROOT"; }
kernel_lifecycle_candidate_path() { printf '%s/candidate.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_certified_path() { printf '%s/certified.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_previous_path() { printf '%s/previous-certified.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_last_promoted_path() { printf '%s/last-promoted.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_rollback_path() { printf '%s/rollback.env' "$(kernel_lifecycle_state_dir)"; }
kernel_lifecycle_policy_path() { printf '%s/config/kernel-lifecycle.policy' "$REPO_ROOT"; }
kernel_lifecycle_ensure_dir() { mkdir -p "$(kernel_lifecycle_state_dir)"; }

kernel_lifecycle_value() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

kernel_lifecycle_policy_value() {
  kernel_lifecycle_value "$(kernel_lifecycle_policy_path)" "$1"
}

kernel_lifecycle_candidate_release() { kernel_lifecycle_value "$(kernel_lifecycle_candidate_path)" release 2>/dev/null || true; }
kernel_lifecycle_certified_release() { kernel_lifecycle_value "$(kernel_lifecycle_certified_path)" release 2>/dev/null || true; }
kernel_lifecycle_previous_release() { kernel_lifecycle_value "$(kernel_lifecycle_previous_path)" release 2>/dev/null || true; }

kernel_lifecycle_release_is_stable() {
  local release="${1,,}"
  [[ -n "$release" ]] || return 1
  [[ "$release" != *linux-next* && "$release" != *mainline* && ! "$release" =~ (^|[-._])rc[0-9]*($|[-._]) ]]
}

kernel_lifecycle_current_certification_valid() {
  local file release fingerprint
  file="$(kernel_lifecycle_certified_path)"
  [[ -s "$file" ]] || return 1
  [[ "$(kernel_lifecycle_value "$file" status 2>/dev/null || true)" == certified ]] || return 1
  release="$(kernel_lifecycle_value "$file" release 2>/dev/null || true)"
  [[ -n "$release" && "$release" == "$(uname -r)" ]] || return 1
  fingerprint="$(kernel_lifecycle_value "$file" fingerprint 2>/dev/null || true)"
  [[ -n "$fingerprint" && "$fingerprint" == "$(workstation_runtime_fingerprint)" ]]
}

kernel_lifecycle_latest_available() {
  dnf -q repoquery --available --latest-limit 1 --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core 2>/dev/null | sort -V | tail -n1
}

kernel_lifecycle_latest_installed_vanilla() {
  rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -F 'vanilla' | sort -V | tail -n1
}

kernel_lifecycle_release_installed() {
  local release="$1"
  rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -Fxq "$release"
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

kernel_lifecycle_require_mutation_gate() {
  runtime_is_baremetal || { ui_error 'Kernel lifecycle mutations are bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_baseline || { ui_error 'Valid hardware baseline required before staging a kernel candidate'; return "$EXIT_PRECHECK_FAILED"; }
  apply_gate_require_backup || { ui_error 'Fresh same-commit pre-APPLY backup required before staging a kernel candidate'; return "$EXIT_PRECHECK_FAILED"; }
  case "$(kernel_lifecycle_secure_boot_state)" in
    disabled) ;;
    enabled) ui_error 'Secure Boot is enabled; candidate staging is blocked by Golden policy'; return "$EXIT_SECURITY_BLOCK" ;;
    *) ui_error 'Secure Boot state is unknown; candidate staging is blocked fail-closed'; return "$EXIT_SECURITY_BLOCK" ;;
  esac
}

kernel_lifecycle_write_marker() {
  local path="$1" release="$2" status="$3"
  shift 3
  kernel_lifecycle_ensure_dir
  {
    printf 'release=%s\n' "$release"
    printf 'status=%s\n' "$status"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'project_commit=%s\n' "$(repo_commit)"
    while (($#)); do printf '%s\n' "$1"; shift; done
  } > "$path"
}

kernel_lifecycle_stage_candidate() {
  kernel_lifecycle_require_mutation_gate
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  command_exists rpm || return "$EXIT_PRECHECK_FAILED"

  local old_default='' available='' installed='' certified=''
  old_default="$(grubby --default-kernel 2>/dev/null || true)"

  sudo dnf -y install dnf5-plugins mokutil grubby grub2-tools-minimal
  sudo dnf -y copr enable "${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}"

  available="$(kernel_lifecycle_latest_available)"
  [[ -n "$available" ]] || { ui_error 'Unable to resolve latest available kernel-core'; return "$EXIT_POSTCHECK_FAILED"; }
  kernel_lifecycle_release_is_stable "$available" || { ui_error "Refusing non-stable kernel candidate: $available"; return "$EXIT_SECURITY_BLOCK"; }
  [[ "$available" == *vanilla* ]] || { ui_error "Resolved candidate is not from Kernel Vanilla: $available"; return "$EXIT_SECURITY_BLOCK"; }

  local -a upgrade_args=()
  is_true "${KERNEL_VENDOR_CHANGE_ALLOWED:-true}" && upgrade_args+=(--setopt=allow_vendor_change=1)
  sudo dnf -y "${upgrade_args[@]}" upgrade kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra perf python3-perf

  installed="$(kernel_lifecycle_latest_installed_vanilla)"
  [[ "$installed" == "$available" ]] || { ui_error "Candidate install mismatch: installed=${installed:-missing} available=$available"; return "$EXIT_POSTCHECK_FAILED"; }

  if [[ -n "$old_default" && -e "$old_default" ]]; then
    sudo grubby --set-default "$old_default"
  fi

  certified="$(kernel_lifecycle_certified_release)"
  kernel_lifecycle_write_marker "$(kernel_lifecycle_candidate_path)" "$installed" candidate \
    "source=${KERNEL_VANILLA_COPR:-@kernel-vanilla/stable}" \
    "certified_at_stage=${certified:-none}" \
    "preserved_default=${old_default:-unknown}"
  ui_check OK 'Kernel candidate' "$installed staged; certified default preserved"
}

kernel_lifecycle_schedule_candidate_once() {
  runtime_is_baremetal || { ui_error 'Candidate boot scheduling is bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  command_exists grubby || return "$EXIT_PRECHECK_FAILED"
  command_exists grub2-reboot || { ui_error 'grub2-reboot is required for one-shot candidate qualification'; return "$EXIT_PRECHECK_FAILED"; }
  local candidate entry_id info
  candidate="$(kernel_lifecycle_candidate_release)"
  [[ -n "$candidate" ]] || { ui_error 'No staged candidate'; return "$EXIT_PRECHECK_FAILED"; }
  kernel_lifecycle_release_installed "$candidate" || { ui_error "Candidate package is not installed: $candidate"; return "$EXIT_POSTCHECK_FAILED"; }
  info="$(grubby --info="/boot/vmlinuz-$candidate" 2>/dev/null || true)"
  entry_id="$(awk -F= '$1=="id" {gsub(/"/,"",$2); print $2; exit}' <<<"$info")"
  [[ -n "$entry_id" ]] || { ui_error "No GRUB/BLS entry found for candidate $candidate"; return "$EXIT_POSTCHECK_FAILED"; }
  sudo grub2-reboot "$entry_id"
  kernel_lifecycle_write_marker "$(kernel_lifecycle_state_dir)/qualification-boot.env" "$candidate" scheduled "entry_id=$entry_id"
  ui_check OK 'One-shot candidate boot' "$candidate scheduled for next reboot only"
}

kernel_lifecycle_certify_candidate() {
  runtime_is_baremetal || { ui_error 'Kernel certification is bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  local candidate running certified fp
  candidate="$(kernel_lifecycle_candidate_release)"
  running="$(uname -r)"
  [[ -n "$candidate" ]] || { ui_error 'No staged candidate to certify'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$running" == "$candidate" ]] || { ui_error "Boot the candidate before certification: running=$running candidate=$candidate"; return "$EXIT_PRECHECK_FAILED"; }
  kernel_lifecycle_release_is_stable "$candidate" || { ui_error "Candidate is not stable: $candidate"; return "$EXIT_SECURITY_BLOCK"; }

  "$REPO_ROOT/diagnostics/final-certification" certify
  fp="$(workstation_runtime_fingerprint)"
  kernel_lifecycle_ensure_dir
  certified="$(kernel_lifecycle_certified_release)"
  if [[ -n "$certified" && -s "$(kernel_lifecycle_certified_path)" && "$certified" != "$candidate" ]]; then
    cp -f "$(kernel_lifecycle_certified_path)" "$(kernel_lifecycle_previous_path)"
  fi
  kernel_lifecycle_write_marker "$(kernel_lifecycle_certified_path)" "$candidate" certified "fingerprint=$fp"
  kernel_lifecycle_current_certification_valid || { ui_error 'Certified kernel marker does not match the current runtime fingerprint'; return "$EXIT_POSTCHECK_FAILED"; }
  cp -f "$(kernel_lifecycle_candidate_path)" "$(kernel_lifecycle_last_promoted_path)"
  rm -f "$(kernel_lifecycle_candidate_path)" "$(kernel_lifecycle_state_dir)/qualification-boot.env"
  sudo grubby --set-default "/boot/vmlinuz-$candidate"
  ui_check OK 'Certified Golden kernel' "$candidate promoted and set as persistent default"
}

kernel_lifecycle_rollback() {
  runtime_is_baremetal || { ui_error 'Kernel rollback is bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  local previous current
  previous="$(kernel_lifecycle_previous_release)"
  current="$(kernel_lifecycle_certified_release)"
  [[ -n "$previous" ]] || { ui_error 'No previous certified kernel is recorded'; return "$EXIT_PRECHECK_FAILED"; }
  kernel_lifecycle_release_installed "$previous" || { ui_error "Previous certified kernel is no longer installed: $previous"; return "$EXIT_POSTCHECK_FAILED"; }
  [[ -e "/boot/vmlinuz-$previous" ]] || { ui_error "Boot image missing for previous certified kernel: $previous"; return "$EXIT_POSTCHECK_FAILED"; }

  kernel_lifecycle_ensure_dir
  [[ -s "$(kernel_lifecycle_certified_path)" ]] && cp -f "$(kernel_lifecycle_certified_path)" "$(kernel_lifecycle_rollback_path)"
  cp -f "$(kernel_lifecycle_previous_path)" "$(kernel_lifecycle_certified_path)"
  rm -f "$(kernel_lifecycle_candidate_path)" "$(kernel_lifecycle_state_dir)/qualification-boot.env"
  sudo grubby --set-default "/boot/vmlinuz-$previous"
  ui_check OK 'Kernel rollback' "default=$previous previous-current=${current:-none}; reboot required"
}

kernel_lifecycle_status() {
  local candidate certified previous running available mode certified_state
  candidate="$(kernel_lifecycle_candidate_release)"
  certified="$(kernel_lifecycle_certified_release)"
  previous="$(kernel_lifecycle_previous_release)"
  running="$(uname -r)"
  available="$(kernel_lifecycle_latest_available 2>/dev/null || true)"
  mode="$(kernel_lifecycle_policy_value mode 2>/dev/null || printf 'candidate-certified')"
  certified_state='not-running'
  if [[ -n "$certified" && "$running" == "$certified" ]]; then
    if kernel_lifecycle_current_certification_valid; then certified_state='valid'; else certified_state='stale'; fi
  fi
  printf 'mode=%s\n' "$mode"
  printf 'running=%s\n' "$running"
  printf 'certified=%s\n' "${certified:-none}"
  printf 'certified_state=%s\n' "$certified_state"
  printf 'candidate=%s\n' "${candidate:-none}"
  printf 'previous_certified=%s\n' "${previous:-none}"
  printf 'latest_available=%s\n' "${available:-unresolved}"
  printf 'fedora_fallback=%s\n' "${KERNEL_KEEP_FEDORA_FALLBACK:-true}"
}
