#!/usr/bin/env bash
# Exercise the production postcheck and doctor with a healthy B580 that has no
# AMD-style busy-percent attribute. All settings, identities and tools are fixtures.
# shellcheck disable=SC2034,SC2016,SC2030,SC2031,SC2317
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
fail() { echo "GNOME telemetry behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/settings" "$tmp/repo/lib" \
  "$tmp/repo/modules/gnome" "$tmp/repo/diagnostics"
touch "$tmp/cpu-present" "$tmp/gpu-present"
printf 'ACTIVE\n' > "$tmp/extension-state"

cat > "$tmp/bin/gsettings" <<SH
#!/usr/bin/env bash
[[ "\$1" != --schemadir ]] || shift 2
case "\$1" in
  get) printf '%s %s\n' "\$2" "\$3" >> "$tmp/settings-reads"; cat "$tmp/settings/\$2.\$3" ;;
  set) printf '%s\n' "\$4" > "$tmp/settings/\$2.\$3" ;;
  *) exit 1 ;;
esac
SH
cat > "$tmp/bin/gnome-extensions" <<SH
#!/usr/bin/env bash
case "\$1" in
  list) echo Vitals@CoreCoding.com ;;
  info)
    [[ "\${LC_ALL:-}" == C ]] || exit 91
    printf 'Enabled: Yes\nState: %s\n' "\$(cat "$tmp/extension-state")" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$tmp/bin/"*

# Preserve the real transformation/check/doctor code and isolate hardware discovery.
cat > "$tmp/repo/lib/bootstrap.sh" <<SH
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/common.sh"
engine_bootstrap() {
  source "$ROOT/config/gnome-extensions.lock"
  source "$ROOT/config/gnome.conf"
  DRY_RUN=false
  REPORT_ROOT="$tmp"
  LOG_DIR="$tmp"
}
runtime_is_baremetal() { return 0; }
run_mutating() { shift; "\$@"; }
log_error() { printf '%s\n' "\$*"; }
log_warn() { printf '%s\n' "\$*"; }
ui_check() { printf '%s|%s|%s\n' "\$@"; }
ui_banner() { :; }
ui_meta() { :; }
ui_summary() { :; }
SH
cat > "$tmp/repo/modules/gnome/24b_resource_monitor.sh" <<SH
source "$ROOT/modules/gnome/24b_resource_monitor.sh"
resource_monitor_find_cpu_sensor() {
  [[ -e "$tmp/cpu-present" ]] || return 1
  printf '/fixture/hwmon/temp1_input|Tctl\n'
}
resource_monitor_find_b580_card() {
  [[ -e "$tmp/gpu-present" ]] || return 1
  printf 'card0\n'
}
# This fixture has no load counter, regardless of the runner's physical GPU.
resource_monitor_gpu_usage_path() { return 1; }
resource_monitor_gpu_temperature_path() { return 1; }
SH
cp "$ROOT/diagnostics/resource-monitor-doctor" "$tmp/repo/diagnostics/"

run_module() {
  (
    export PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_DATA_HOME="$tmp/data"
    REPO_ROOT="$tmp/repo"
    source "$tmp/repo/lib/bootstrap.sh"
    engine_bootstrap
    source "$tmp/repo/modules/gnome/24b_resource_monitor.sh"
    "$@"
  )
}
run_doctor() {
  PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" XDG_CURRENT_DESKTOP=GNOME \
    bash "$tmp/repo/diagnostics/resource-monitor-doctor" > "$tmp/doctor.log" 2>&1
}
extension_dir="$tmp/data/gnome-shell/extensions/Vitals@CoreCoding.com"
mkdir -p "$extension_dir/schemas"
printf '{}\n' > "$extension_dir/metadata.json"
touch "$extension_dir/schemas/gschemas.compiled"
source "$ROOT/config/gnome-extensions.lock"
printf 'source_url=%s\nreview_id=%s\nsite_version=%s\n' \
  "$RESOURCE_MONITOR_SOURCE_URL" "$RESOURCE_MONITOR_REVIEW_ID" "$RESOURCE_MONITOR_VERSION" \
  > "$extension_dir/.fedora-gnome-custom-source"

run_module resource_monitor_vitals_apply
run_module gnome_telemetry_postcheck > "$tmp/postcheck.log" 2>&1 || {
  cat "$tmp/postcheck.log" >&2
  fail 'healthy B580 without a busy-percent attribute blocks the postcheck'
}
run_doctor || { cat "$tmp/doctor.log" >&2; fail 'healthy B580 without GPU load blocks the doctor'; }
grep -Fq 'EXPECTED|B580 GPU load source|' "$tmp/doctor.log" || fail 'unmeasured load not identified explicitly'
if grep -Eq 'value=0%|load[^|]*\|[^|]*0%' "$tmp/doctor.log"; then fail 'missing GPU load was synthesized as zero'; fi
[[ "$(cat "$tmp/settings/org.gnome.shell.extensions.vitals.show-gpu")" == false ]] || fail 'unqualified GPU indicator enabled by default'
for key in show-processor show-memory show-network; do
  [[ "$(cat "$tmp/settings/org.gnome.shell.extensions.vitals.$key")" == true ]] || fail "$key disabled"
done

# CPU, RAM and network settings remain required; optional GPU load cannot hide drift.
for key in show-processor show-memory show-network; do
  printf 'false\n' > "$tmp/settings/org.gnome.shell.extensions.vitals.$key"
  rc=0; run_module gnome_telemetry_postcheck > "$tmp/postcheck.log" 2>&1 || rc=$?
  [[ "$rc" -eq 40 ]] || fail "$key drift accepted by postcheck (rc=$rc)"
  if run_doctor; then fail "$key drift accepted by doctor"; fi
  printf 'true\n' > "$tmp/settings/org.gnome.shell.extensions.vitals.$key"
done
for marker in cpu-present gpu-present; do
  rm "$tmp/$marker"
  rc=0; run_module gnome_telemetry_postcheck > "$tmp/postcheck.log" 2>&1 || rc=$?
  [[ "$rc" -eq 40 ]] || fail "missing $marker accepted by postcheck (rc=$rc)"
  if run_doctor; then fail "missing $marker accepted by doctor"; fi
  touch "$tmp/$marker"
done
printf 'ERROR\n' > "$tmp/extension-state"
rc=0; run_module gnome_telemetry_postcheck > "$tmp/postcheck.log" 2>&1 || rc=$?
[[ "$rc" -eq 40 ]] || fail 'extension ERROR accepted by postcheck'
if run_doctor; then fail 'extension ERROR accepted by doctor'; fi

# Exercise both real Gate 2 doctor blocks, including payload, provenance and
# extension state. The remaining VM/session checks do not run on the host.
python3 -B - "$ROOT" "$tmp" <<'PY'
from pathlib import Path
import sys
root, temp = map(Path, sys.argv[1:])
doctor = (root / 'diagnostics/virtualbox-gnome-lab-doctor').read_text()
functions = doctor[doctor.index('\nemit() {'):doctor.index('\nif ! $quiet; then ui_banner')]
blocks = doctor[doctor.index('show_uuid='):doctor.index("\ncheck_value 'Window buttons'")]
(temp / 'lab-extension-checks.sh').write_text(functions + '\n' + blocks + '\n')
PY
run_lab_checks() {
  local profile="$1" drift="${2:-none}"
  (
    export PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_DATA_HOME="$tmp/data"
    REPO_ROOT="$tmp/repo"
    source "$tmp/repo/lib/bootstrap.sh"
    engine_bootstrap
    source "$ROOT/profiles/fedora$profile/gnome-extensions.lock"
    source "$ROOT/modules/gnome/24_gnome_extensions.sh"
    source "$tmp/repo/modules/gnome/24b_resource_monitor.sh"
    local prefix uuid_key url_key review_key version_key directory
    for prefix in SHOW_DESKTOP_PLUS RESOURCE_MONITOR; do
      uuid_key="${prefix}_UUID"; url_key="${prefix}_SOURCE_URL"
      review_key="${prefix}_REVIEW_ID"; version_key="${prefix}_VERSION"
      directory="$XDG_DATA_HOME/gnome-shell/extensions/${!uuid_key}"
      mkdir -p "$directory"
      printf '{}\n' > "$directory/metadata.json"
      printf 'source_url=%s\nreview_id=%s\nsite_version=%s\n' \
        "${!url_key}" "${!review_key}" "${!version_key}" > "$directory/.fedora-gnome-custom-source"
    done
    # Invoked by the real doctor functions sourced below.
    # shellcheck disable=SC2329
    gnome-extensions() {
      case "$1" in
        list) printf '%s\n' "$SHOW_DESKTOP_PLUS_UUID" "$RESOURCE_MONITOR_UUID" ;;
        info) [[ "${LC_ALL:-}" == C ]] || return 91; printf 'Enabled: Yes\nState: ACTIVE\n' ;;
        *) return 99 ;;
      esac
    }
    gnome_show_desktop_plus_settings_apply
    if resource_monitor_is_vitals; then
      resource_monitor_vitals_apply
      [[ "$drift" != cpu ]] || printf 'false\n' > "$tmp/settings/$RESOURCE_MONITOR_SCHEMA.show-processor"
      [[ "$drift" != desktop ]] || printf "['<Super>x']\n" > "$tmp/settings/$SHOW_DESKTOP_PLUS_SCHEMA.show-desktop-shortcut"
    else
      local key value
      while IFS='|' read -r key value; do
        printf '%s\n' "$value" > "$tmp/settings/$RESOURCE_MONITOR_SCHEMA.$key"
      done <<'SETTINGS'
refreshtime|2
cpustatus|true
ramstatus|true
netethstatus|true
netwlanstatus|true
gpustatus|false
diskstatsstatus|false
swapstatus|false
SETTINGS
      [[ "$drift" != cpu ]] || printf 'false\n' > "$tmp/settings/$RESOURCE_MONITOR_SCHEMA.cpustatus"
      [[ "$drift" != desktop ]] || printf "['<Super>x']\n" > "$tmp/settings/$SHOW_DESKTOP_PLUS_SCHEMA.show-desktop-hotkey"
    fi
    [[ "$drift" != provenance ]] || rm "$directory/.fedora-gnome-custom-source"
    quiet=false; ok=0; expected=0; ko=0
    : > "$tmp/settings-reads"
    source "$tmp/lab-extension-checks.sh"
    ((ko == 0))
  ) > "$tmp/lab-doctor.log" 2>&1
}
run_lab_checks 45 || { cat "$tmp/lab-doctor.log" >&2; fail 'Gate 2 doctor rejected healthy GNOME 51 variants'; }
if grep -Eq 'org.gnome.shell.extensions.vitals (refreshtime|cpustatus|ramstatus|netethstatus|netwlanstatus|gpustatus|diskstatsstatus|swapstatus)$|org.gnome.shell.extensions.show-desktop-button (button-position|left-click-action|enable-hotkey|show-desktop-hotkey|show-hidden-count)$' "$tmp/settings-reads"; then
  fail 'GNOME 51 variants queried obsolete settings'
fi
for profile in 45 44; do
  run_lab_checks "$profile" || { cat "$tmp/lab-doctor.log" >&2; fail "healthy Gate 2 profile $profile rejected"; }
  for drift in cpu desktop provenance; do
    if run_lab_checks "$profile" "$drift"; then fail "Gate 2 profile $profile accepted $drift drift"; fi
  done
done

echo 'GNOME telemetry behavior: PASS (B580 load optional, CPU/RAM/network and identities required)'
