#!/usr/bin/env bash

physical_hw_state_dir() { printf '%s/hardware\n' "$STATE_ROOT"; }
physical_bt_lock_path() { printf '%s/bluetooth-identity.env\n' "$(physical_hw_state_dir)"; }
physical_cooling_lock_path() { printf '%s/cooling-channels.env\n' "$(physical_hw_state_dir)"; }

physical_bluetooth_identity() {
  runtime_is_baremetal || return 1
  local root hci node driver='' vendor='' product=''
  root="$(hardware_platform_sysfs_root)"
  for hci in "$root"/class/bluetooth/hci*; do
    [[ -e "$hci/device" ]] || continue
    node="$(readlink -f "$hci/device")"
    while [[ -n "$node" && "$node" != / && "$node" == "$root"/* ]]; do
      if [[ -z "$driver" && -L "$node/driver" ]]; then driver="$(basename "$(readlink -f "$node/driver")")"; fi
      if [[ -r "$node/idVendor" && -r "$node/idProduct" ]]; then
        vendor="$(tr '[:upper:]' '[:lower:]' < "$node/idVendor")"
        product="$(tr '[:upper:]' '[:lower:]' < "$node/idProduct")"
        break
      fi
      node="$(dirname "$node")"
    done
    [[ "$vendor" =~ ^[0-9a-f]{4}$ && "$product" =~ ^[0-9a-f]{4}$ && -n "$driver" ]] || continue
    printf 'hci=%s\nusb_id=%s:%s\ndriver=%s\n' "${hci##*/}" "$vendor" "$product" "$driver"
    return 0
  done
  return 1
}

physical_bluetooth_identity_value() {
  local key="$1" data
  data="$(physical_bluetooth_identity)" || return 1
  awk -F= -v key="$key" '$1==key {print $2; exit}' <<<"$data"
}

physical_enroll_bluetooth() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  hardware_platform_validate_dmi || return "$EXIT_PRECHECK_FAILED"
  local usb driver hci path
  usb="$(physical_bluetooth_identity_value usb_id)" || return "$EXIT_PRECHECK_FAILED"
  driver="$(physical_bluetooth_identity_value driver)" || return "$EXIT_PRECHECK_FAILED"
  hci="$(physical_bluetooth_identity_value hci)" || return "$EXIT_PRECHECK_FAILED"
  [[ "$driver" == btusb ]] || { ui_error "Bluetooth must use Fedora in-tree btusb; got $driver"; return "$EXIT_PRECHECK_FAILED"; }
  path="$(physical_bt_lock_path)"; mkdir -p "$(dirname "$path")"
  {
    printf 'schema=1\nboard_name=%s\nhci=%s\nusb_id=%s\ndriver=%s\nenrolled_utc=%s\n' \
      "$(hardware_platform_board_name)" "$hci" "$usb" "$driver" "$(date -u +%FT%TZ)"
  } | evidence_atomic_write "$path" 0600
  printf '%s\n' "$path"
}

physical_bluetooth_lock_valid() {
  runtime_is_baremetal || return 1
  local path usb driver board
  path="$(physical_bt_lock_path)"; [[ -s "$path" ]] || return 1
  grep -Fxq 'schema=1' "$path" || return 1
  usb="$(physical_bluetooth_identity_value usb_id 2>/dev/null || true)"
  driver="$(physical_bluetooth_identity_value driver 2>/dev/null || true)"
  board="$(awk -F= '$1=="board_name" {sub(/^board_name=/,""); print; exit}' "$path")"
  [[ "$board" == "$(hardware_platform_board_name)" && "$driver" == btusb ]] || return 1
  grep -Fxq "usb_id=$usb" "$path" && grep -Fxq 'driver=btusb' "$path"
}

physical_cooling_list() {
  local chip f channel rpm label
  chip="$(hardware_platform_hwmon_chip_dir)" || return 1
  for f in "$chip"/fan*_input; do
    [[ -r "$f" ]] || continue
    channel="$(basename "$f" _input)"; rpm="$(<"$f")"; label=''
    [[ -r "$chip/${channel}_label" ]] && label="$(<"$chip/${channel}_label")"
    printf '%s rpm=%s label=%s\n' "$channel" "$rpm" "${label:-unlabeled}"
  done
}

physical_cooling_channel_rpm() {
  local channel="$1" chip
  [[ "$channel" =~ ^fan[0-9]+$ ]] || return 1
  chip="$(hardware_platform_hwmon_chip_dir)" || return 1
  [[ -r "$chip/${channel}_input" ]] || return 1
  cat "$chip/${channel}_input"
}

physical_enroll_cooling() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  local pump="$1" cpu="$2" system="$3" min="${HARDWARE_COOLING_MIN_RPM:-100}" path role ch rpm
  [[ "$pump" != "$cpu" && "$pump" != "$system" && "$cpu" != "$system" ]] || { ui_error 'Cooling channels must be three distinct fanN inputs'; return "$EXIT_PRECHECK_FAILED"; }
  for role in pump cpu system; do
    case "$role" in pump) ch="$pump";; cpu) ch="$cpu";; system) ch="$system";; esac
    rpm="$(physical_cooling_channel_rpm "$ch" 2>/dev/null || true)"
    if [[ ! "$rpm" =~ ^[0-9]+$ ]]; then
      ui_error "$role cooling channel $ch is unavailable or below ${min} RPM"
      return "$EXIT_PRECHECK_FAILED"
    fi
    if (( rpm < min )); then
      ui_error "$role cooling channel $ch is unavailable or below ${min} RPM"
      return "$EXIT_PRECHECK_FAILED"
    fi
  done
  path="$(physical_cooling_lock_path)"; mkdir -p "$(dirname "$path")"
  {
    printf 'schema=1\nboard_name=%s\npump=%s\ncpu=%s\nsystem=%s\nmin_rpm=%s\nenrolled_utc=%s\n' \
      "$(hardware_platform_board_name)" "$pump" "$cpu" "$system" "$min" "$(date -u +%FT%TZ)"
  } | evidence_atomic_write "$path" 0600
  printf '%s\n' "$path"
}

physical_cooling_lock_valid() {
  runtime_is_baremetal || return 1
  local path board min role ch rpm
  path="$(physical_cooling_lock_path)"; [[ -s "$path" ]] || return 1
  grep -Fxq 'schema=1' "$path" || return 1
  board="$(awk -F= '$1=="board_name" {sub(/^board_name=/,""); print; exit}' "$path")"
  [[ "$board" == "$(hardware_platform_board_name)" ]] || return 1
  min="$(awk -F= '$1=="min_rpm" {print $2; exit}' "$path")"; [[ "$min" =~ ^[0-9]+$ ]] || return 1
  for role in pump cpu system; do
    ch="$(awk -F= -v role="$role" '$1==role {print $2; exit}' "$path")"
    rpm="$(physical_cooling_channel_rpm "$ch" 2>/dev/null || true)"
    [[ "$rpm" =~ ^[0-9]+$ ]] || return 1
    (( rpm >= min )) || return 1
  done
}

physical_cpu_temp_millic() {
  local root hwmon name f v max=-1
  root="$(hardware_platform_sysfs_root)/class/hwmon"
  for hwmon in "$root"/hwmon*; do
    [[ -d "$hwmon" ]] || continue
    name="$(hardware_platform_value "$hwmon/name" '')"
    [[ "$name" == k10temp ]] || continue
    for f in "$hwmon"/temp*_input; do
      [[ -r "$f" ]] || continue; v="$(<"$f")"
      [[ "$v" =~ ^[0-9]+$ ]] || continue; (( v > max )) && max="$v"
    done
  done
  (( max >= 0 )) || return 1
  printf '%s\n' "$max"
}

physical_runtime_evidence_dir() { printf '%s/final/evidence\n' "$STATE_ROOT"; }
physical_runtime_fingerprint_payload() {
  printf 'hardware=%s\n' "$(baseline_fingerprint)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'drivers=%s\n' "$(driver_contract_fingerprint)"
  printf 'linux_firmware=%s\n' "$(runtime_component_version linux-firmware)"
  printf 'mesa_vulkan=%s\n' "$(runtime_component_version mesa-vulkan-drivers)"
  printf 'pipewire=%s\n' "$(runtime_component_version pipewire)"
  printf 'mutter=%s\n' "$(runtime_component_version mutter)"
}
physical_runtime_fingerprint() { physical_runtime_fingerprint_payload | sha256sum | awk '{print $1}'; }
physical_runtime_evidence_path() { printf '%s/%s.ok\n' "$(physical_runtime_evidence_dir)" "$1"; }
physical_runtime_write_evidence() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  local name="$1" detail="$2" path
  path="$(physical_runtime_evidence_path "$name")"; mkdir -p "$(dirname "$path")"
  {
    printf 'schema=1\nname=%s\nstatus=PASS\nfingerprint=%s\neffective_config_sha256=%s\ndisplay_edid_sha256=%s\nutc=%s\ndetail=%s\n' \
      "$name" "$(physical_runtime_fingerprint)" "$(effective_config_sha256)" "$(hardware_b580_expected_edid_sha256 2>/dev/null || echo unavailable)" "$(date -u +%FT%TZ)" "$detail"
  } | evidence_atomic_write "$path" 0600
}
physical_runtime_evidence_valid() {
  runtime_is_baremetal || return 1
  local name="$1" path
  path="$(physical_runtime_evidence_path "$name")"; [[ -s "$path" ]] || return 1
  if [[ "$name" == gpu-soak ]]; then
    physical_soak_evidence_detail_valid gpu "$(sed -n 's/^detail=//p' "$path")" || return 1
  fi
  grep -Fxq 'status=PASS' "$path" \
    && grep -Fxq "fingerprint=$(physical_runtime_fingerprint)" "$path" \
    && grep -Fxq "effective_config_sha256=$(effective_config_sha256)" "$path"
}

# Qualification workloads have minimum durations; shortened smoke tests cannot
# write hardware PASS evidence. Bound integers before Bash arithmetic.
physical_soak_uint_between() {
  local value="$1" minimum="$2" maximum="$3"
  [[ "$value" =~ ^[1-9][0-9]{0,5}$ ]] || return 1
  (( value >= minimum && value <= maximum ))
}
physical_soak_parameters_valid() {
  local kind="$1" seconds="$2" instances="${3:-1}" minimum
  case "$kind" in cpu) minimum=1800;; memory) minimum=3600;; gpu) minimum=900;; *) return 1;; esac
  physical_soak_uint_between "$seconds" "$minimum" 86400 || return 1
  physical_soak_uint_between "$instances" 1 8
}
physical_cpu_sample_checked() {
  local maximum="$1" sample
  physical_soak_uint_between "$maximum" 50000 95000 || return 1
  sample="$(physical_cpu_temp_millic)" || { echo 'CPU temperature sensor unavailable' >&2; return 1; }
  physical_soak_uint_between "$sample" 1 120000 || { echo 'CPU temperature sample invalid' >&2; return 1; }
  (( sample < maximum )) || { echo "CPU temperature reached safety limit: ${sample}m°C (limit ${maximum})" >&2; return 1; }
  printf '%s\n' "$sample"
}
# Each workload runs in its own session. Stop its workers too, with a bounded
# grace period, when a measurement fails or the operator interrupts the test.
physical_stop_process_group() {
  local pid="${1:-}" attempt
  [[ "$pid" =~ ^[1-9][0-9]{0,8}$ ]] || return 0
  kill -TERM -- "-$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true
  for ((attempt=0; attempt<30; attempt++)); do
    kill -0 -- "-$pid" 2>/dev/null || kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -KILL -- "-$pid" 2>/dev/null || true
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

physical_soak_detail_value() {
  local detail="$1" key="$2"
  awk -v key="$key" '{for(i=1;i<=NF;i++) if(index($i,key "=")==1){sub("^" key "=","",$i); value=$i; count++}} END {if(count!=1) exit 1; print value}' <<<"$detail"
}
physical_soak_evidence_detail_valid() {
  local kind="$1" detail="$2" policy seconds elapsed instances=1
  policy="$(physical_soak_detail_value "$detail" qualification_policy)" || return 1
  [[ "$policy" == 2 ]] || return 1
  seconds="$(physical_soak_detail_value "$detail" seconds)" || return 1
  elapsed="$(physical_soak_detail_value "$detail" elapsed_seconds)" || return 1
  if [[ "$kind" == gpu ]]; then instances="$(physical_soak_detail_value "$detail" instances)" || return 1; fi
  physical_soak_parameters_valid "$kind" "$seconds" "$instances" || return 1
  physical_soak_uint_between "$elapsed" "$seconds" 172800
}

physical_soak_invalidate_evidence() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  local name="$1" path
  case "$name" in
    gpu-soak) path="$(physical_runtime_evidence_path "$name")";;
    cpu-soak|memory-5600|memory-6000) path="$(baseline_evidence_dir)/$name.ok";;
    *) return 1;;
  esac
  rm -f -- "$path" "$STATE_ROOT/final/certified.ok"
  if [[ "$name" != gpu-soak ]]; then rm -f -- "$(baseline_certification_path)"; fi
}
