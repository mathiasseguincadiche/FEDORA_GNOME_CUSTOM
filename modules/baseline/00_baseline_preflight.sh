#!/usr/bin/env bash
set -Eeuo pipefail
baseline_preflight_precheck() {
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || return "$EXIT_PRECHECK_FAILED"
  fedora_require_selected || return "$EXIT_PRECHECK_FAILED"
  [[ -d /sys/firmware/efi ]] || return "$EXIT_PRECHECK_FAILED"
  command_exists lscpu || return "$EXIT_PRECHECK_FAILED"
  command_exists sha256sum || return "$EXIT_PRECHECK_FAILED"
}
baseline_preflight_plan() { echo 'Read-only Phase 0 gate: selected Fedora release, UEFI and hardware identity are validated before any workstation personalization.'; }
baseline_preflight_apply() { log_info BASELINE 'read-only baseline: no mutation'; }
baseline_preflight_postcheck() { baseline_fingerprint_payload >> "$MODULE_LOG"; }
