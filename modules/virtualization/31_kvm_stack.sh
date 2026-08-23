#!/usr/bin/env bash
set -Eeuo pipefail

kvm_stack_operator() {
  local operator="${SUDO_USER:-${USER:-}}"
  [[ -n "$operator" && "$operator" != root ]] || return 1
  printf '%s\n' "$operator"
}

kvm_stack_unit_exists() {
  local unit="$1"
  systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -Fq "$unit"
}

kvm_stack_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists dnf && command_exists systemctl && command_exists sudo || return "$EXIT_PRECHECK_FAILED"
  kvm_stack_operator >/dev/null || { log_error KVM 'real operator user cannot be resolved'; return "$EXIT_PRECHECK_FAILED"; }
}

kvm_stack_plan() {
  cat <<'EOF'
FEDORA LIBVIRT STACK:
- install QEMU/KVM, libvirt clients/drivers and complete administration tooling
- prefer Fedora/libvirt modular socket activation (virtqemud, virtnetworkd, virtstoraged)
- fall back to libvirtd.socket only when modular units are genuinely unavailable
- install virt-manager and virt-viewer as explicit virtualization exceptions to GTK4 policy
- install OVMF, swtpm tools, VirtioFS, guestfs and libosinfo tooling
- grant the operator libvirt,kvm groups idempotently
EOF
}

kvm_stack_apply() {
  local operator unit found_modular=false
  is_true "${ENABLE_KVM:-true}" || return 0
  operator="$(kvm_stack_operator)" || return "$EXIT_APPLY_FAILED"

  install_manifest_packages KVM "$REPO_ROOT/manifests/packages-virtualization.txt" || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: modular libvirt socket discovery occurs after package installation during real APPLY'
  else
    for unit in virtqemud.socket virtnetworkd.socket virtstoraged.socket; do
      if kvm_stack_unit_exists "$unit"; then
        found_modular=true
        run_mutating KVM sudo systemctl enable --now "$unit" || return "$EXIT_APPLY_FAILED"
      fi
    done
    for unit in virtlogd.socket virtlockd.socket; do
      kvm_stack_unit_exists "$unit" && run_mutating KVM sudo systemctl enable --now "$unit" || true
    done
    if [[ "$found_modular" != true ]]; then
      kvm_stack_unit_exists libvirtd.socket || { log_error KVM 'no supported libvirt socket activation model found'; return "$EXIT_APPLY_FAILED"; }
      run_mutating KVM sudo systemctl enable --now libvirtd.socket || return "$EXIT_APPLY_FAILED"
    fi
  fi

  if ! id -nG "$operator" | tr ' ' '\n' | grep -Fxq libvirt || ! id -nG "$operator" | tr ' ' '\n' | grep -Fxq kvm; then
    run_mutating KVM sudo usermod -aG "${KVM_OPERATOR_GROUPS:-libvirt,kvm}" "$operator" || return "$EXIT_APPLY_FAILED"
  fi
}

kvm_stack_postcheck() {
  local operator
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  operator="$(kvm_stack_operator)" || return "$EXIT_POSTCHECK_FAILED"

  for cmd in virsh qemu-img virt-install virt-clone virt-manager virt-viewer remote-viewer swtpm swtpm_setup virtiofsd osinfo-query; do
    command_exists "$cmd" || { log_error KVM "missing virtualization command: $cmd"; return "$EXIT_POSTCHECK_FAILED"; }
  done

  virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virsh --connect "${LIBVIRT_URI:-qemu:///system}" capabilities >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  id -nG "$operator" | tr ' ' '\n' | grep -Fxq libvirt || return "$EXIT_POSTCHECK_FAILED"
  id -nG "$operator" | tr ' ' '\n' | grep -Fxq kvm || return "$EXIT_POSTCHECK_FAILED"
  log_warn KVM 'a logout/login may be required before the current desktop session inherits new libvirt/kvm groups'
}
