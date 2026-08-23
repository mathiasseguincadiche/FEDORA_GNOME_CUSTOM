#!/usr/bin/env bash
set -Eeuo pipefail
kvm_validation_precheck() { :; }
kvm_validation_plan() { echo 'Validate qemu:///system, NAT network, OVMF and swtpm availability.'; }
kvm_validation_apply() { :; }
kvm_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_KVM:-true}" || return 0
  virsh -c qemu:///system list >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  command_exists virt-install && command_exists swtpm || return "$EXIT_POSTCHECK_FAILED"
}
