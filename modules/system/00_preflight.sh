#!/usr/bin/env bash
set -Eeuo pipefail

system_preflight_collect() {
  local report="$REPORT_ROOT/$RUN_ID-system-preflight.txt"
  {
    echo '[os-release]'; cat /etc/os-release
    echo '[kernel]'; uname -a
    echo '[cpu]'; lscpu
    echo '[pci]'; lspci -nnk
    echo '[storage]'; lsblk -o NAME,MODEL,SIZE,FSTYPE,MOUNTPOINTS
    echo '[mounts]'; findmnt -rn -o TARGET,FSTYPE,OPTIONS
    echo '[memory]'; free -h
    echo '[selinux]'; getenforce 2>/dev/null || true
    echo '[secure-boot]'
    if command -v mokutil >/dev/null 2>&1; then mokutil --sb-state 2>&1 || true; else echo 'mokutil unavailable'; fi
    echo '[kvm]'; if [[ -c /dev/kvm ]]; then echo present; else echo missing; fi
    echo '[boot-errors]'; journalctl -k -b -p warning..alert --no-pager 2>/dev/null || true
  } > "$report"
  printf '%s\n' "$report"
}

system_preflight_precheck() {
  [[ $EUID -ne 0 ]] || { log_error SYSTEM 'run as normal user; sudo is invoked only for required mutations'; return "$EXIT_PRECHECK_FAILED"; }
  local cmd
  for cmd in bash sudo dnf rpm lscpu lspci lsblk findmnt systemctl journalctl; do
    command_exists "$cmd" || { log_error SYSTEM "missing command: $cmd"; return "$EXIT_PRECHECK_FAILED"; }
  done
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || return "$EXIT_PRECHECK_FAILED"
  fedora_require_selected || { log_error SYSTEM 'Selected promoted Fedora release required'; return "$EXIT_PRECHECK_FAILED"; }
  system_preflight_collect >/dev/null
  if is_true "${HARDWARE_MATCH_REQUIRED:-true}"; then
    lscpu | grep -Fq "$EXPECTED_CPU" || { log_error SYSTEM "CPU mismatch: expected $EXPECTED_CPU"; return "$EXIT_PRECHECK_FAILED"; }
    lspci -nn | grep -Eqi '8086:e20b|\[8086:e20b\]' || { log_error SYSTEM 'Intel Arc B580 PCI 8086:e20b not found'; return "$EXIT_PRECHECK_FAILED"; }
  fi
}
system_preflight_plan() { echo 'READ-ONLY: validate selected Fedora release, hardware identity, mounts, SELinux, KVM availability and preserve an inventory report.'; }
system_preflight_apply() { :; }
system_preflight_postcheck() { [[ -s "$REPORT_ROOT/$RUN_ID-system-preflight.txt" ]]; }
