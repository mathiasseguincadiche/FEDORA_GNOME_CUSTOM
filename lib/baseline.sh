#!/usr/bin/env bash

baseline_state_dir(){ printf '%s/baseline' "$STATE_ROOT"; }
baseline_evidence_dir(){ printf '%s/evidence' "$(baseline_state_dir)"; }
baseline_certification_path(){ printf '%s/certified.ok' "$(baseline_state_dir)"; }
baseline_ensure_dirs(){ mkdir -p "$(baseline_evidence_dir)"; }
baseline_hw_value(){ local path="$1" fallback="${2:-unknown}"; if [[ -r "$path" ]]; then tr -d '\000' < "$path" | head -n1; else printf '%s\n' "$fallback"; fi; }
baseline_cpu_model(){ awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || printf 'unknown\n'; }

baseline_find_expected_gpu(){ local dev vendor device driver expected_vendor expected_device; expected_vendor="$(normalize_hex "${EXPECTED_GPU_PCI_VENDOR:-8086}")"; expected_device="$(normalize_hex "${EXPECTED_GPU_PCI_DEVICE:-e20b}")"; for dev in /sys/bus/pci/devices/*; do [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue; vendor="$(normalize_hex "$(<"$dev/vendor")")"; device="$(normalize_hex "$(<"$dev/device")")"; [[ "$vendor" == "$expected_vendor" && "$device" == "$expected_device" ]] || continue; driver=unbound; [[ -L "$dev/driver" ]] && driver="$(basename "$(readlink -f "$dev/driver")")"; printf '%s|%s\n' "${dev##*/}" "$driver"; return 0; done; return 1; }
baseline_gpu_inventory(){ local found driver; found="$(baseline_find_expected_gpu 2>/dev/null || true)"; [[ -n "$found" ]] || { printf 'missing\n'; return; }; driver="${found#*|}"; printf '%s:%s|driver=%s\n' "${EXPECTED_GPU_PCI_VENDOR:-8086}" "${EXPECTED_GPU_PCI_DEVICE:-e20b}" "$driver"; }
baseline_nvme_inventory(){ local d; for d in /sys/class/nvme/nvme*; do [[ -d "$d" ]] || continue; printf 'model=%s|serial=%s|firmware=%s\n' "$(baseline_hw_value "$d/model")" "$(baseline_hw_value "$d/serial")" "$(baseline_hw_value "$d/firmware_rev")"; done | sort; }
baseline_nvme_model_count(){ baseline_nvme_inventory | grep -Fc "model=${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" || true; }
baseline_memory_inventory(){ printf 'mem_total_kib=%s|expected_gib=%s|tested_mt_s=%s,%s\n' "$(awk '/MemTotal/ {print $2}' /proc/meminfo)" "${EXPECTED_RAM_GIB:-48}" "${BASELINE_MEMORY_SPD_MT_S:-5600}" "${BASELINE_MEMORY_XMP_MT_S:-6000}"; }
baseline_edid_hashes(){ local f; for f in /sys/class/drm/card*-*/edid; do [[ -s "$f" ]] || continue; printf 'edid=%s\n' "$(sha256sum "$f" | awk '{print $1}')"; done | sort; }

baseline_fingerprint_payload(){
  printf 'board_vendor=%s\n' "$(baseline_hw_value /sys/class/dmi/id/board_vendor)"
  printf 'board=%s\n' "$(baseline_hw_value /sys/class/dmi/id/board_name)"
  printf 'bios_vendor=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_vendor)"
  printf 'bios=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_version)"
  printf 'bios_date=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_date)"
  printf 'product_uuid=%s\n' "$(baseline_hw_value /sys/class/dmi/id/product_uuid)"
  printf 'cpu=%s\n' "$(baseline_cpu_model)"
  printf 'cpu_scaling_driver=%s\n' "$(hardware_platform_cpu_scaling_driver 2>/dev/null || echo unknown)"
  printf 'amd_pstate=%s\n' "$(hardware_platform_cpu_pstate_status 2>/dev/null || echo unknown)"
  printf 'cpu_boost=%s\n' "$(hardware_platform_cpu_boost_value 2>/dev/null || echo unknown)"
  printf 'gpu=%s\n' "$(baseline_gpu_inventory)"
  printf '[memory]\n%s\n' "$(baseline_memory_inventory)"
  printf '[nvme]\n%s\n' "$(baseline_nvme_inventory)"
  printf '[edid]\n%s\n' "$(baseline_edid_hashes)"
}
baseline_fingerprint(){ baseline_fingerprint_payload | sha256sum | awk '{print $1}'; }

baseline_write_evidence(){ runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"; local name="$1" status="$2" detail="${3:-}" path; baseline_ensure_dirs; path="$(baseline_evidence_dir)/$name.ok"; { printf 'name=%s\nstatus=%s\nutc=%s\nfingerprint=%s\ndetail=%s\n' "$name" "$status" "$(date -u +%FT%TZ)" "$(baseline_fingerprint)" "$detail"; } | evidence_atomic_write "$path" 0600; }
baseline_evidence_valid(){ runtime_is_baremetal || return 1; local name="$1" file; file="$(baseline_evidence_dir)/$name.ok"; [[ -s "$file" ]] || return 1; grep -Fxq 'status=PASS' "$file" || return 1; grep -Fxq "fingerprint=$(baseline_fingerprint)" "$file" || return 1; case "$name" in memory-5600|memory-6000|nvme-root|nvme-data|cpu-soak) grep -Eq '^detail=.*automated=true.*sha256=[0-9a-f]{64}' "$file";; esac; }
baseline_evidence_device(){ awk -F'device=' '/^detail=/ {split($2,a," "); print a[1]; exit}' "$(baseline_evidence_dir)/$1.ok"; }

baseline_automatic_health_check(){
  runtime_is_baremetal || return 1
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || return 1
  lscpu 2>/dev/null | grep -Fq "${EXPECTED_CPU:-AMD Ryzen 7 7700}" || return 1
  hardware_platform_validate_dmi || { log_error BASELINE 'MSI MAG B850M MORTAR WIFI DMI/AMI BIOS validation failed'; return 1; }
  hardware_platform_validate_cpu_power || { log_error BASELINE 'Ryzen AMD P-State/boost validation failed'; return 1; }
  hardware_platform_wifi_lock_valid || { log_error BASELINE 'Wi-Fi identity lock missing/stale'; return 1; }
  physical_bluetooth_lock_valid || { log_error BASELINE 'Bluetooth USB/btusb identity lock missing/stale'; return 1; }
  hardware_platform_validate_hwmon || { log_error BASELINE 'NCT6687D hwmon validation failed'; return 1; }
  physical_cooling_lock_valid || { log_error BASELINE 'pump/CPU/system fan channel lock missing/stale'; return 1; }
  driver_contract_validate || { log_error BASELINE 'critical kernel driver binding/provenance contract failed'; return 1; }
  local gpu driver severe=0
  gpu="$(baseline_find_expected_gpu)" || return 1; driver="${gpu#*|}"; [[ "$driver" == "${EXPECTED_GPU_KERNEL_DRIVER:-xe}" ]] || return 1
  (( $(baseline_nvme_model_count) >= ${EXPECTED_NVME_COUNT:-2} )) || return 1
  hardware_b580_pcie_validate || { log_error BASELINE 'Arc B580 PCIe x8 / ReBAR validation failed'; return 1; }
  storage_nvme_validate_all_expected || { log_error BASELINE 'strict T705 SMART/PCIe health validation failed'; return 1; }
  severe="$(journalctl -k -b --no-pager 2>/dev/null | grep -Eic 'kernel panic|Oops:|watchdog.*hard LOCKUP|MCE:.*Hardware Error|Machine Check|EDAC.*(UE|uncorrected)|xe.*(wedged|reset failed)|PCIe Bus Error: severity=Uncorrected|nvme.*(I/O error|reset controller)' || true)"
  (( severe == 0 ))
}

baseline_certify(){
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  baseline_evidence_valid memory-5600 || return 1; baseline_evidence_valid memory-6000 || return 1
  baseline_evidence_valid nvme-root || return 1; baseline_evidence_valid nvme-data || return 1
  baseline_evidence_valid cpu-soak || return 1
  local rd dd path
  rd="$(baseline_evidence_device nvme-root)"; dd="$(baseline_evidence_device nvme-data)"
  [[ -n "$rd" && -n "$dd" && "$rd" != "$dd" ]] || { log_error BASELINE 'root and /data must be backed by two distinct physical NVMe devices'; return 1; }
  baseline_automatic_health_check || return 1
  hardware_b580_capture_display_profile || { log_error BASELINE 'unable to bind exactly one 2560x1440 display EDID to the Arc B580'; return 1; }
  baseline_ensure_dirs; path="$(baseline_certification_path)"
  {
    printf 'verdict=PASS\nfingerprint=%s\ncertified_utc=%s\nmemory_5600=PASS\nmemory_6000=PASS\ncpu_soak=PASS\nnvme_root=%s\nnvme_data=%s\n' "$(baseline_fingerprint)" "$(date -u +%FT%TZ)" "$rd" "$dd"
    printf 'display_edid_sha256=%s\n' "$(hardware_b580_expected_edid_sha256)"
    printf 'dmi_platform=PASS\namd_pstate=PASS\ncpu_boost=PASS\nwifi_identity_lock=PASS\nbluetooth_identity_lock=PASS\nnct6687_hwmon=PASS\ncooling_channels=PASS\n'
    printf 'driver_contract=PASS\nb580_pcie_x8=PASS\nrebar=PASS\nt705_pcie_x4=PASS\n'
  } | evidence_atomic_write "$path" 0600
}

baseline_certification_valid(){
  runtime_is_baremetal || return 1
  local marker; marker="$(baseline_certification_path)"; [[ -s "$marker" ]] || return 1
  for required in verdict=PASS dmi_platform=PASS amd_pstate=PASS cpu_boost=PASS wifi_identity_lock=PASS bluetooth_identity_lock=PASS nct6687_hwmon=PASS cooling_channels=PASS driver_contract=PASS cpu_soak=PASS; do grep -Fxq "$required" "$marker" || return 1; done
  grep -Fxq "fingerprint=$(baseline_fingerprint)" "$marker" || return 1
  hardware_platform_wifi_lock_valid || return 1
  physical_bluetooth_lock_valid || return 1
  physical_cooling_lock_valid || return 1
  baseline_evidence_valid cpu-soak || return 1
  driver_contract_validate || return 1
  [[ "$(evidence_marker_value "$marker" display_edid_sha256 2>/dev/null || true)" == "$(hardware_b580_expected_edid_sha256)" ]]
}

runtime_component_version(){ local pkg="$1" version; version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$pkg" 2>/dev/null || true)"; printf '%s\n' "${version:-missing}"; }
workstation_runtime_fingerprint_payload(){ local pkg; printf 'hardware=%s\n' "$(baseline_fingerprint)"; printf 'kernel=%s\n' "$(uname -r)"; if runtime_is_baremetal; then printf 'drivers=%s\n' "$(driver_contract_fingerprint)"; printf 'applications=%s\n' "$(application_runtime_fingerprint)"; if is_true "${ENABLE_KVM:-true}"; then printf 'kvm=%s\n' "$(kvm_contract_fingerprint)"; fi; fi; for pkg in ${FINAL_CERT_FINGERPRINT_PACKAGES:-linux-firmware intel-gpu-firmware mesa-dri-drivers mesa-vulkan-drivers mutter gnome-shell}; do printf '%s=%s\n' "$pkg" "$(runtime_component_version "$pkg")"; done; }
workstation_runtime_fingerprint(){ workstation_runtime_fingerprint_payload | sha256sum | awk '{print $1}'; }
