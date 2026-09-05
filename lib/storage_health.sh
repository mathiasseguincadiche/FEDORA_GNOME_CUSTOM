#!/usr/bin/env bash
# Strict NVMe health and PCIe qualification for the two Golden Crucial T705 controllers.
# shellcheck disable=SC2153

storage_nvme_expected_controllers() {
  local sys model
  for sys in /sys/class/nvme/nvme[0-9]*; do
    [[ -d "$sys" ]] || continue
    model="$(baseline_hw_value "$sys/model" '')"
    [[ "$model" == "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" ]] || continue
    printf '/dev/%s\n' "${sys##*/}"
  done | sort -V
}

storage_nvme_health_json() {
  local dev="$1"
  command -v smartctl >/dev/null 2>&1 || return 1
  if smartctl -a -j "$dev" 2>/dev/null; then
    return 0
  fi
  command -v sudo >/dev/null 2>&1 || return 1
  sudo -n smartctl -a -j "$dev" 2>/dev/null
}

storage_nvme_health_summary() {
  python3 -c 'import json,sys
j=json.load(sys.stdin)
n=j.get("nvme_smart_health_information_log") or {}
def v(name, default=0):
    x=n.get(name, default)
    if isinstance(x, dict):
        x=x.get("current", x.get("value", default))
    return x
fields=(
    ("critical_warning", v("critical_warning")),
    ("temperature_c", v("temperature")),
    ("available_spare", v("available_spare")),
    ("available_spare_threshold", v("available_spare_threshold")),
    ("percentage_used", v("percentage_used")),
    ("media_errors", v("media_errors")),
    ("error_log_entries", v("num_err_log_entries")),
)
for k,x in fields: print(f"{k}={x}")'
}

storage_nvme_controller_bdf() {
  local dev="$1" name="${1#/dev/}" path
  path="/sys/class/nvme/$name/device"
  [[ -e "$path" ]] || return 1
  basename "$(readlink -f "$path")"
}

storage_nvme_pcie_validate() {
  local dev="$1" bdf sys curw maxw maxs
  bdf="$(storage_nvme_controller_bdf "$dev")" || return 1
  sys="/sys/bus/pci/devices/$bdf"
  curw="$(baseline_hw_value "$sys/current_link_width" 0)"
  maxw="$(baseline_hw_value "$sys/max_link_width" 0)"
  maxs="$(hardware_pcie_speed_gts "$(baseline_hw_value "$sys/max_link_speed" 0)" 2>/dev/null || printf 0)"
  [[ "$curw" =~ ^[0-9]+$ && "$maxw" =~ ^[0-9]+$ ]] || return 1
  (( curw >= 4 && maxw >= 4 )) || return 1
  # T705 is a PCIe 5.0 x4 device; certify capability, not idle-time negotiated speed.
  awk -v s="$maxs" 'BEGIN { exit !(s >= 32.0) }'
}

storage_nvme_validate_controller() {
  local dev="$1" json summary critical temp spare threshold used media
  json="$(storage_nvme_health_json "$dev" 2>/dev/null || true)"
  [[ -n "$json" ]] || return 1
  summary="$(printf '%s\n' "$json" | storage_nvme_health_summary 2>/dev/null || true)"
  critical="$(awk -F= '$1=="critical_warning"{print $2}' <<<"$summary")"
  temp="$(awk -F= '$1=="temperature_c"{print $2}' <<<"$summary")"
  spare="$(awk -F= '$1=="available_spare"{print $2}' <<<"$summary")"
  threshold="$(awk -F= '$1=="available_spare_threshold"{print $2}' <<<"$summary")"
  used="$(awk -F= '$1=="percentage_used"{print $2}' <<<"$summary")"
  media="$(awk -F= '$1=="media_errors"{print $2}' <<<"$summary")"
  for value in "$critical" "$temp" "$spare" "$threshold" "$used" "$media"; do [[ "$value" =~ ^[0-9]+$ ]] || return 1; done
  (( critical == 0 )) || return 1
  (( media == 0 )) || return 1
  (( spare >= threshold )) || return 1
  (( used <= ${NVME_MAX_PERCENTAGE_USED:-90} )) || return 1
  (( temp <= ${NVME_MAX_TEMP_C:-85} )) || return 1
  storage_nvme_pcie_validate "$dev"
}

storage_nvme_kernel_health() {
  ! journalctl -k -b --no-pager 2>/dev/null | grep -Eqi \
    'nvme.*(I/O error|reset controller|controller is down|device not ready|timeout)|PCIe Bus Error: severity=Uncorrected|AER:.*Uncorrected'
}

storage_nvme_validate_all_expected() {
  local -a devices=()
  local dev
  mapfile -t devices < <(storage_nvme_expected_controllers)
  (( ${#devices[@]} == ${EXPECTED_NVME_COUNT:-2} )) || return 1
  for dev in "${devices[@]}"; do
    storage_nvme_validate_controller "$dev" || return 1
  done
  storage_nvme_kernel_health
}
