#!/usr/bin/env bash
set -Eeuo pipefail
hardware_cpu_memory_precheck() { command_exists dnf; }
hardware_cpu_memory_plan() { echo 'Install hardware observability, validate Ryzen 7 7700, AMD P-State when exposed, 48 GiB RAM and inventory configured DDR5 speed without changing BIOS settings.'; }
hardware_cpu_memory_apply() { install_manifest_packages HARDWARE "$REPO_ROOT/manifests/packages-hardware.txt"; run_mutating HARDWARE sudo systemctl enable --now rasdaemon.service; }
hardware_cpu_memory_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  lscpu | grep -Fq "$EXPECTED_CPU" || return "$EXIT_POSTCHECK_FAILED"
  local mem_kib min_kib; mem_kib="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"; min_kib=$((45*1024*1024)); (( mem_kib >= min_kib )) || return "$EXIT_POSTCHECK_FAILED"
  if [[ -r /sys/devices/system/cpu/amd_pstate/status ]]; then log_info HARDWARE "amd_pstate=$(cat /sys/devices/system/cpu/amd_pstate/status)"; else log_warn HARDWARE 'amd_pstate status not exposed'; fi
  local configured; configured="$(sudo dmidecode --type 17 2>/dev/null | awk -F: '/Configured Memory Speed:/ {gsub(/^[ \t]+/,"",$2); print $2}' | sort -u | paste -sd, -)" || true
  [[ -n "$configured" ]] && log_info HARDWARE "configured-memory-speed=$configured (kit specification: ${EXPECTED_RAM_MT_S} MT/s)"
}
