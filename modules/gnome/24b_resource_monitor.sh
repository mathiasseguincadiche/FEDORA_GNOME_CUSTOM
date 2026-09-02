#!/usr/bin/env bash
set -Eeuo pipefail

resource_monitor_extension_dir() {
  printf '%s/%s' "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions" "${RESOURCE_MONITOR_UUID:-Resource_Monitor@Ory0n}"
}

resource_monitor_schema_dir() {
  printf '%s/schemas' "$(resource_monitor_extension_dir)"
}

resource_monitor_find_cpu_sensor() {
  local hwmon chip input base label fallback=""
  for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -d "$hwmon" && -r "$hwmon/name" ]] || continue
    chip="$(<"$hwmon/name")"
    case "$chip" in k10temp|zenpower) ;; *) continue ;; esac
    for input in "$hwmon"/temp*_input; do
      [[ -r "$input" ]] || continue
      base="${input%_input}"
      label="$(cat "${base}_label" 2>/dev/null || true)"
      [[ -n "$fallback" ]] || fallback="$input|${label:-$chip}"
      if [[ "$label" == "Tctl" ]]; then
        printf '%s|%s\n' "$input" "$label"
        return 0
      fi
    done
  done
  [[ -n "$fallback" ]] || return 1
  printf '%s\n' "$fallback"
}

resource_monitor_find_b580_card() {
  local card vendor device
  for card in /sys/class/drm/card[0-9]*; do
    [[ -r "$card/device/vendor" && -r "$card/device/device" ]] || continue
    vendor="$(tr '[:upper:]' '[:lower:]' < "$card/device/vendor")"
    device="$(tr '[:upper:]' '[:lower:]' < "$card/device/device")"
    if [[ "$vendor" == "0x8086" && "$device" == "0xe20b" ]]; then
      basename "$card"
      return 0
    fi
  done
  return 1
}

resource_monitor_gpu_usage_path() {
  local card="$1" candidate
  for candidate in \
    "/sys/class/drm/$card/device/gpu_busy_percent" \
    "/sys/class/drm/$card/device/gt_busy_percent"; do
    [[ -r "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

resource_monitor_gpu_temperature_path() {
  local card="$1" path
  for path in "/sys/class/drm/$card/device/hwmon"/hwmon*/temp*_input; do
    [[ -r "$path" ]] && { printf '%s\n' "$path"; return 0; }
  done
  return 1
}

resource_monitor_json_cpu() {
  python3 - "$1" "$2" <<'PY'
import json, sys
print(json.dumps({"version": 2, "type": "thermal-cpu", "name": sys.argv[1], "monitor": True, "path": sys.argv[2]}, separators=(",", ":")))
PY
}

resource_monitor_json_gpu() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps({"version": 2, "type": "gpu", "device": f"intel:{sys.argv[1]}", "name": "Intel Arc B580", "usage": True, "memory": False, "displayName": "Arc B580"}, separators=(",", ":")))
PY
}

resource_monitor_json_gpu_thermal() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps({"version": 2, "type": "thermal-gpu", "device": f"intel:{sys.argv[1]}", "name": "Intel Arc B580", "monitor": True}, separators=(",", ":")))
PY
}

resource_monitor_set() {
  local key="$1" value="$2"
  run_mutating GNOME gsettings --schemadir "$(resource_monitor_schema_dir)" set \
    "${RESOURCE_MONITOR_SCHEMA:-org.gnome.shell.extensions.resource-monitor}" "$key" "$value"
}

gnome_telemetry_precheck() {
  is_true "${ENABLE_RESOURCE_MONITOR:-false}" || return 0
  [[ "${RESOURCE_MONITOR_UUID:-}" == "Resource_Monitor@Ory0n" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_SOURCE_URL:-}" == "https://extensions.gnome.org/review/download/70909.shell-extension.zip" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_REVIEW_ID:-}" == "70909" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_VERSION:-}" == "28" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_SHELL_VERSION:-}" == "50" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_SCHEMA:-}" == "org.gnome.shell.extensions.resource-monitor" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${RESOURCE_MONITOR_REFRESH_SECONDS:-}" == "2" ]] || return "$EXIT_PRECHECK_FAILED"
  command_exists python3 || return "$EXIT_PRECHECK_FAILED"
}

gnome_telemetry_plan() {
  cat <<'EOF'
RESOURCE MONITOR PLAN:
- install Resource Monitor v28 from GNOME Extensions reviewed artifact 70909 (GNOME Shell 50)
- top-right compact telemetry: CPU usage + Ryzen Tctl, RAM used %, active Ethernet/Wi-Fi download|upload, Intel Arc B580 load + temperature
- disk and swap indicators stay hidden from the top bar to keep the panel readable
- network entries auto-hide when the corresponding interface is inactive
- Intel B580 GPU load is fail-closed on bare metal: no readable xe usage source means postcheck failure, never a fake 0%
EOF
}

gnome_telemetry_apply() {
  local uuid="${RESOURCE_MONITOR_UUID:-Resource_Monitor@Ory0n}"
  local cpu_sensor cpu_path cpu_label cpu_json
  local gpu_card gpu_json gpu_thermal_json
  is_true "${ENABLE_RESOURCE_MONITOR:-false}" || return 0

  run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-resource-monitor.sh" \
    "${RESOURCE_MONITOR_SOURCE_URL:-}" "$uuid" "${RESOURCE_MONITOR_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"

  resource_monitor_set refreshtime "${RESOURCE_MONITOR_REFRESH_SECONDS:-2}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set extensionposition "'${RESOURCE_MONITOR_POSITION:-right}'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set displaymode "'primary'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set iconsstatus "${RESOURCE_MONITOR_SHOW_ICONS:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set itemsposition "['cpu', 'ram', 'eth', 'wlan', 'gpu']" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set cpustatus "${RESOURCE_MONITOR_CPU_USAGE:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set cpufrequencystatus false || return "$EXIT_APPLY_FAILED"
  resource_monitor_set cpuloadaveragestatus false || return "$EXIT_APPLY_FAILED"
  resource_monitor_set ramstatus "${RESOURCE_MONITOR_RAM:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set ramunit "'perc'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set rammonitor "'used'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set swapstatus false || return "$EXIT_APPLY_FAILED"
  resource_monitor_set diskstatsstatus false || return "$EXIT_APPLY_FAILED"
  resource_monitor_set diskspacestatus false || return "$EXIT_APPLY_FAILED"
  resource_monitor_set netautohidestatus true || return "$EXIT_APPLY_FAILED"
  resource_monitor_set netunit "'bytes'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set netunitmeasure "'auto'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set netethstatus "${RESOURCE_MONITOR_NETWORK:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set netwlanstatus "${RESOURCE_MONITOR_NETWORK:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set thermaltemperatureunit "'c'" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set thermalcputemperaturestatus "${RESOURCE_MONITOR_CPU_TEMPERATURE:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set thermalgputemperaturestatus "${RESOURCE_MONITOR_GPU_TEMPERATURE:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set gpustatus "${RESOURCE_MONITOR_GPU_USAGE:-true}" || return "$EXIT_APPLY_FAILED"
  resource_monitor_set gpudisplaydevicename false || return "$EXIT_APPLY_FAILED"

  if ! is_true "${DRY_RUN:-true}"; then
    if cpu_sensor="$(resource_monitor_find_cpu_sensor 2>/dev/null)"; then
      cpu_path="${cpu_sensor%%|*}"
      cpu_label="${cpu_sensor#*|}"
      cpu_json="$(resource_monitor_json_cpu "$cpu_label" "$cpu_path")"
      resource_monitor_set thermalcputemperaturedeviceslist "['$cpu_json']" || return "$EXIT_APPLY_FAILED"
    else
      log_warn GNOME 'Resource Monitor: no k10temp/zenpower CPU sensor detected yet'
    fi

    if gpu_card="$(resource_monitor_find_b580_card 2>/dev/null)"; then
      gpu_json="$(resource_monitor_json_gpu "$gpu_card")"
      gpu_thermal_json="$(resource_monitor_json_gpu_thermal "$gpu_card")"
      resource_monitor_set gpudeviceslist "['$gpu_json']" || return "$EXIT_APPLY_FAILED"
      resource_monitor_set thermalgputemperaturedeviceslist "['$gpu_thermal_json']" || return "$EXIT_APPLY_FAILED"
    else
      log_warn GNOME 'Resource Monitor: Intel Arc B580 8086:e20b is not visible in DRM sysfs'
    fi

    if declare -F gnome_extension_enable_checked >/dev/null; then
      gnome_extension_enable_checked 'Resource Monitor' "$uuid" || return "$EXIT_APPLY_FAILED"
    else
      gnome-extensions enable "$uuid" || return "$EXIT_APPLY_FAILED"
    fi
  fi
}

gnome_telemetry_postcheck() {
  local uuid="${RESOURCE_MONITOR_UUID:-Resource_Monitor@Ory0n}"
  local schema="${RESOURCE_MONITOR_SCHEMA:-org.gnome.shell.extensions.resource-monitor}"
  local schema_dir extension_dir gpu_card
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_RESOURCE_MONITOR:-false}" || return 0
  extension_dir="$(resource_monitor_extension_dir)"
  schema_dir="$(resource_monitor_schema_dir)"

  [[ -r "$extension_dir/metadata.json" ]] || return "$EXIT_POSTCHECK_FAILED"
  grep -Fxq "source_url=${RESOURCE_MONITOR_SOURCE_URL:-}" "$extension_dir/.fedora-gnome-custom-source" || return "$EXIT_POSTCHECK_FAILED"
  grep -Fxq "review_id=${RESOURCE_MONITOR_REVIEW_ID:-}" "$extension_dir/.fedora-gnome-custom-source" || return "$EXIT_POSTCHECK_FAILED"
  gnome-extensions info "$uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" cpustatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" ramstatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" netethstatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" netwlanstatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" gpustatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(gsettings --schemadir "$schema_dir" get "$schema" thermalcputemperaturestatus)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"

  if runtime_is_baremetal; then
    resource_monitor_find_cpu_sensor >/dev/null || { log_error GNOME 'Resource Monitor cannot resolve Ryzen CPU temperature sensor'; return "$EXIT_POSTCHECK_FAILED"; }
    gpu_card="$(resource_monitor_find_b580_card 2>/dev/null)" || { log_error GNOME 'Resource Monitor cannot resolve Intel Arc B580 8086:e20b'; return "$EXIT_POSTCHECK_FAILED"; }
    resource_monitor_gpu_usage_path "$gpu_card" >/dev/null || { log_error GNOME 'Resource Monitor has no readable B580 xe GPU load source (gpu_busy_percent/gt_busy_percent)'; return "$EXIT_POSTCHECK_FAILED"; }
    if is_true "${RESOURCE_MONITOR_GPU_TEMPERATURE:-true}" && ! resource_monitor_gpu_temperature_path "$gpu_card" >/dev/null; then
      log_warn GNOME 'Resource Monitor: B580 temperature hwmon source unavailable; GPU load remains mandatory'
    fi
  fi
}
