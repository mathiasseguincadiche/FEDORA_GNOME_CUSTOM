#!/usr/bin/env bash
set -Eeuo pipefail
baseline_memory_precheck() { [[ -r /proc/meminfo ]]; }
baseline_memory_plan() { echo 'Phase 0 requires operator evidence for both DDR5-5600 SPD and DDR5-6000 XMP after memory testing; no BIOS memory setting is changed automatically.'; }
baseline_memory_apply() { log_info BASELINE 'memory certification remains operator-controlled'; }
baseline_memory_postcheck() {
  local mem_kib
  mem_kib="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  (( mem_kib >= 45*1024*1024 )) || return "$EXIT_POSTCHECK_FAILED"
  log_info BASELINE "memory-total-kib=$mem_kib kit=${EXPECTED_RAM_MT_S:-6000}MT/s"
  if ! is_true "${DRY_RUN:-true}"; then
    baseline_evidence_valid memory-5600 || return "$EXIT_POSTCHECK_FAILED"
    baseline_evidence_valid memory-6000 || return "$EXIT_POSTCHECK_FAILED"
  fi
}
