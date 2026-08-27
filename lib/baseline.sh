#!/usr/bin/env bash

baseline_state_dir() { printf '%s/baseline' "$STATE_ROOT"; }
baseline_evidence_dir() { printf '%s/evidence' "$(baseline_state_dir)"; }
baseline_certification_path() { printf '%s/certified.ok' "$(baseline_state_dir)"; }

baseline_ensure_dirs() {
  mkdir -p "$(baseline_evidence_dir)"
}

baseline_hw_value() {
  local path="$1" fallback="${2:-unknown}"
  if [[ -r "$path" ]]; then tr -d '\000' < "$path" | head -n1; else printf '%s\n' "$fallback"; fi
}

baseline_cpu_model() {
  awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || printf 'unknown\n'
}

baseline_find_expected_gpu() {
  local dev vendor device driver
  local expected_vendor expected_device
  expected_vendor="$(normalize_hex "${EXPECTED_GPU_PCI_VENDOR:-8086}")"
  expected_device="$(normalize_hex "${EXPECTED_GPU_PCI_DEVICE:-e20b}")"
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(normalize_hex "$(<"$dev/vendor")")"
    device="$(normalize_hex "$(<"$dev/device")")"
    [[ "$vendor" == "$expected_vendor" && "$device" == "$expected_device" ]] || continue
    driver="unbound"
    [[ -L "$dev/driver" ]] && driver="$(basename "$(readlink -f "$dev/driver")")"
    printf '%s|%s\n' "${dev##*/}" "$driver"
    return 0
  done
  return 1
}

baseline_nvme_model_count() {
  local model count=0
  for model in /sys/class/nvme/nvme*/model; do
    [[ -r "$model" ]] || continue
    grep -Fq "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" "$model" && ((count+=1))
  done
  printf '%d\n' "$count"
}

baseline_fingerprint_payload() {
  printf 'board=%s\n' "$(baseline_hw_value /sys/class/dmi/id/board_name)"
  printf 'bios=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_version)"
  printf 'bios_date=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_date)"
  printf 'cpu=%s\n' "$(baseline_cpu_model)"
  printf 'gpu=%s\n' "$(baseline_find_expected_gpu 2>/dev/null || printf 'missing')"
  printf 'nvme_count=%s\n' "$(baseline_nvme_model_count)"
}

baseline_fingerprint() {
  baseline_fingerprint_payload | sha256sum | awk '{print $1}'
}

baseline_write_evidence() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  local name="$1" status="$2" detail="${3:-}"
  baseline_ensure_dirs
  {
    printf 'name=%s\n' "$name"
    printf 'status=%s\n' "$status"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'fingerprint=%s\n' "$(baseline_fingerprint)"
    printf 'detail=%s\n' "$detail"
  } > "$(baseline_evidence_dir)/$name.ok"
}

baseline_evidence_valid() {
  runtime_is_baremetal || return 1
  local name="$1" file
  file="$(baseline_evidence_dir)/$name.ok"
  [[ -s "$file" ]] || return 1
  grep -Fxq 'status=PASS' "$file" || return 1
  grep -Fxq "fingerprint=$(baseline_fingerprint)" "$file"
}

baseline_suspend_pass_count() {
  runtime_is_baremetal || { printf '0\n'; return 0; }
  local file count=0
  shopt -s nullglob
  for file in "$(baseline_evidence_dir)"/suspend-cycle-*.ok; do
    grep -Fxq 'status=PASS' "$file" || continue
    grep -Fxq "fingerprint=$(baseline_fingerprint)" "$file" || continue
    ((count+=1))
  done
  shopt -u nullglob
  printf '%d\n' "$count"
}

baseline_automatic_health_check() {
  runtime_is_baremetal || return 1
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || return 1
  lscpu 2>/dev/null | grep -Fq "${EXPECTED_CPU:-AMD Ryzen 7 7700}" || return 1
  local gpu driver
  gpu="$(baseline_find_expected_gpu)" || return 1
  driver="${gpu#*|}"
  [[ "$driver" == "${EXPECTED_GPU_KERNEL_DRIVER:-xe}" ]] || return 1
  (( $(baseline_nvme_model_count) >= ${EXPECTED_NVME_COUNT:-2} )) || return 1

  local severe=0
  if command_exists journalctl; then
    severe="$(journalctl -k -b --no-pager 2>/dev/null | grep -Eic 'kernel panic|Oops:|watchdog.*hard LOCKUP|MCE:.*Hardware Error|EDAC.*(UE|uncorrected)|xe.*(wedged|reset failed)|PCIe Bus Error: severity=Uncorrected|nvme.*(I/O error|reset controller)' || true)"
  fi
  (( severe == 0 ))
}

baseline_certify() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  baseline_evidence_valid memory-5600 || return 1
  baseline_evidence_valid memory-6000 || return 1
  baseline_evidence_valid nvme-io || return 1
  (( $(baseline_suspend_pass_count) >= ${BASELINE_MIN_SUSPEND_CYCLES:-5} )) || return 1
  baseline_automatic_health_check || return 1
  baseline_ensure_dirs
  {
    printf 'verdict=PASS\n'
    printf 'fingerprint=%s\n' "$(baseline_fingerprint)"
    printf 'certified_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'memory_5600=PASS\n'
    printf 'memory_6000=PASS\n'
    printf 'nvme_io=PASS\n'
    printf 'suspend_cycles=%s\n' "$(baseline_suspend_pass_count)"
  } > "$(baseline_certification_path)"
}

baseline_certification_valid() {
  runtime_is_baremetal || return 1
  local marker
  marker="$(baseline_certification_path)"
  [[ -s "$marker" ]] || return 1
  grep -Fxq 'verdict=PASS' "$marker" || return 1
  grep -Fxq "fingerprint=$(baseline_fingerprint)" "$marker"
}
