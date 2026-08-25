#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap

report="$REPORT_ROOT/$RUN_ID-workstation-certification.txt"
: > "$report"
pass=0
fail=0
minimum_stress_minutes=30
minimum_suspend_cycles="${POWER_SUSPEND_CERTIFICATION_CYCLES:-10}"
expected_memory_speed="${EXPECTED_RAM_MT_S} MT/s"

record_pass() { printf 'PASS %s\n' "$1" | tee -a "$report"; ((pass+=1)); }
record_fail() { printf 'FAIL %s\n' "$1" | tee -a "$report"; ((fail+=1)); }
run_doctor() {
  local name="$1" doctor="$2"
  if "$REPO_ROOT/diagnostics/$doctor" >> "$report" 2>&1; then record_pass "$name"; else record_fail "$name"; fi
}

run_doctor kernel kernel-doctor
run_doctor topology hardware-topology-doctor
run_doctor power power-doctor
run_doctor graphics graphics-doctor
run_doctor storage storage-doctor
run_doctor network network-doctor
run_doctor audio audio-doctor
run_doctor display display-pipeline-doctor

if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* && "${XDG_SESSION_TYPE:-}" == wayland ]]; then
  record_pass 'GNOME Wayland session'
else
  record_fail "GNOME Wayland session (desktop=${XDG_CURRENT_DESKTOP:-unknown}, session=${XDG_SESSION_TYPE:-unknown})"
fi

default_if="$(ip route show default 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')"
if [[ -n "$default_if" && "$(cat "/sys/class/net/$default_if/operstate" 2>/dev/null || true)" == up ]]; then
  record_pass "active default uplink ($default_if)"
else
  record_fail 'active default uplink'
fi

if command -v wpctl >/dev/null 2>&1 && wpctl status >/dev/null 2>&1 && command -v aplay >/dev/null 2>&1 && aplay -l 2>/dev/null | grep -q '^card ' && lsmod | grep -q '^snd_usb_audio'; then
  record_pass 'ALC4080 audio path (ALSA + snd_usb_audio + PipeWire/WirePlumber)'
else
  record_fail 'ALC4080 audio path (ALSA + snd_usb_audio + PipeWire/WirePlumber)'
fi

if command -v gdbus >/dev/null 2>&1; then
  display_state="$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null || true)"
else
  display_state=""
fi
if [[ -n "$display_state" ]] && grep -q "$EXPECTED_WIDTH" <<< "$display_state" && grep -q "$EXPECTED_HEIGHT" <<< "$display_state" && grep -Eq "${EXPECTED_REFRESH_HZ}([.]0+)?|239([.][0-9]+)?" <<< "$display_state"; then
  record_pass "Mutter mode ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}@${EXPECTED_REFRESH_HZ}Hz"
else
  record_fail "Mutter mode ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}@${EXPECTED_REFRESH_HZ}Hz"
fi

stress_result="$STATE_ROOT/stability-stress/latest/result.env"
stress_minutes=""
stress_speed=""
stress_profile=""
if [[ -r "$stress_result" ]]; then
  stress_minutes="$(awk -F= '$1=="minutes" {print $2; exit}' "$stress_result")"
  stress_speed="$(awk -F= '$1=="configured_memory_speed" {print $2; exit}' "$stress_result")"
  stress_profile="$(awk -F= '$1=="memory_profile" {print $2; exit}' "$stress_result")"
fi
if [[ -r "$stress_result" ]] && grep -Fqx 'result=PASS' "$stress_result" && [[ "$stress_minutes" =~ ^[0-9]+$ ]] && (( stress_minutes >= minimum_stress_minutes )) && [[ "$stress_speed" == "$expected_memory_speed" && "$stress_profile" == "${EXPECTED_MEMORY_PROFILE:-}" ]]; then
  record_pass "stability-stress >=30m DDR5-6000 ($stress_minutes min, $stress_speed, $stress_profile)"
else
  record_fail "stability-stress >=30m DDR5-6000 (minutes=${stress_minutes:-missing}, speed=${stress_speed:-missing}, profile=${stress_profile:-missing})"
fi

suspend_result="$STATE_ROOT/suspend-certification/latest/result.env"
suspend_cycles=""
if [[ -r "$suspend_result" ]]; then suspend_cycles="$(awk -F= '$1=="cycles" {print $2; exit}' "$suspend_result")"; fi
if [[ -r "$suspend_result" ]] && grep -Fqx 'result=PASS' "$suspend_result" && [[ "$suspend_cycles" =~ ^[0-9]+$ ]] && (( suspend_cycles >= minimum_suspend_cycles )); then
  record_pass "suspend/resume certification >=${minimum_suspend_cycles} cycles ($suspend_cycles)"
else
  record_fail "suspend/resume certification >=${minimum_suspend_cycles} cycles (${suspend_cycles:-missing})"
fi

printf 'PASS=%d FAIL=%d\n' "$pass" "$fail" | tee -a "$report"
if (( fail == 0 )); then
  printf 'VERDICT=PASS\n' | tee -a "$report"
  exit 0
fi
printf 'VERDICT=FAIL\n' | tee -a "$report"
exit 20
