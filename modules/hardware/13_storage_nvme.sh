#!/usr/bin/env bash
set -Eeuo pipefail
hardware_storage_precheck() { command_exists dnf; }
hardware_storage_plan() { echo 'Install NVMe/SMART tools; validate both Crucial T705 devices, health, media errors, critical warnings and temperatures. Never alter scheduler/APST/ASPM automatically.'; }
hardware_storage_apply() { run_mutating HARDWARE sudo dnf -y install nvme-cli smartmontools; }
hardware_storage_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local report="$REPORT_ROOT/$RUN_ID-nvme-health.txt" count d
  {
    sudo nvme list
    echo
    sudo nvme list-subsys
    echo
    for d in /dev/nvme[0-9]; do
      [[ -e "$d" ]] || continue
      sudo nvme smart-log "$d" || true
    done
  } > "$report" 2>&1
  count="$(grep -c "$EXPECTED_NVME_MODEL" "$report" || true)"
  if is_true "${HARDWARE_MATCH_REQUIRED:-true}"; then (( count >= EXPECTED_NVME_COUNT )) || { log_error HARDWARE "expected ${EXPECTED_NVME_COUNT} T705, found $count"; return "$EXIT_POSTCHECK_FAILED"; }; fi
  if ! grep -Eqi 'critical_warning[[:space:]]*:[[:space:]]*0|critical_warning[[:space:]]*:[[:space:]]*0x0' "$report"; then log_warn HARDWARE 'review NVMe critical warning fields manually'; fi
}
