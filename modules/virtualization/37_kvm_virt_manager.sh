#!/usr/bin/env bash
set -Eeuo pipefail

kvm_virt_manager_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  return 0
}

kvm_virt_manager_plan() {
  cat <<'EOF'
GRAPHICAL VIRTUALIZATION MANAGEMENT:
- keep virt-manager as the primary graphical VM administration tool
- keep virt-viewer/remote-viewer for guest consoles
- this scope is an explicit exception to the GTK4/libadwaita desktop-only policy
- use qemu:///system; do not create a second session-mode libvirt estate
- preserve Fedora/libvirt defaults rather than writing fragile per-user GUI settings
EOF
}

kvm_virt_manager_apply() { :; }

kvm_virt_manager_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists virt-manager && command_exists virt-viewer && command_exists remote-viewer || return "$EXIT_POSTCHECK_FAILED"
  rpm -q virt-manager virt-viewer >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
