#!/usr/bin/env bash
set -Eeuo pipefail
kvm_preflight_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  grep -Eq 'svm|AMD-V' <(lscpu) || return "$EXIT_PRECHECK_FAILED"
  [[ -c /dev/kvm ]] || { log_error KVM '/dev/kvm missing; verify SVM in UEFI'; return "$EXIT_PRECHECK_FAILED"; }
  is_true "${ALLOW_GPU_PASSTHROUGH:-false}" && { log_error KVM 'GPU passthrough is forbidden by workstation policy'; return "$EXIT_PRECHECK_FAILED"; }
}
kvm_preflight_plan() { echo 'Validate AMD-V/KVM and preserve Intel Arc B580 ownership on the HOST.'; }
kvm_preflight_apply() { :; }
kvm_preflight_postcheck() { :; }
