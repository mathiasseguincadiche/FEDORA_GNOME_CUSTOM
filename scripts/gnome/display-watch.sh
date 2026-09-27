#!/usr/bin/env bash
set -Eeuo pipefail
repair="$HOME/.local/libexec/fedora-gnome-display-repair"
[[ -x "$repair" ]] || exit 0
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom"; mkdir -p "$state_dir"
policy="$state_dir/display-policy.env"
[[ -r "$policy" ]] || { echo "Display policy missing: $policy" >&2; exit 1; }
# Installed by the module from schema-validated configuration.
source "$policy"
[[ "${DISPLAY_REPAIR_ENABLED:-false}" == true ]] || exit 0
trigger(){
  local reason="$1" action="$2" lock="$state_dir/display-repair.lock"
  (
    flock 9
    if [[ "$action" == --restore ]]; then sleep 1; fi
    rc=0
    "$repair" "$action" >> "$state_dir/display-repair-watch.log" 2>&1 || rc=$?
    printf '%s reason=%s rc=%s\n' "$(date -u +%FT%TZ)" "$reason" "$rc" >> "$state_dir/display-repair-watch.log"
  ) 9>"$lock"
}
watch_sleep(){
  gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *PrepareForSleep*true*) trigger suspend --snapshot ;;
      *PrepareForSleep*false*) trigger resume --restore ;;
    esac
  done
}
watch_mutter(){
  gdbus monitor --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig 2>/dev/null | while IFS= read -r line; do
    # Observation only: user changes must never replay an old layout.
    [[ "$line" != *MonitorsChanged* ]] || trigger mutter-monitors-changed --check
  done
}
watch_drm(){
  udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while IFS= read -r line; do
    [[ "$line" != *change*drm* ]] || trigger drm-hotplug --check
  done
}
pids=()
if [[ "${DISPLAY_REPAIR_ON_RESUME:-false}" == true ]]; then watch_sleep & pids+=("$!"); fi
if [[ "${DISPLAY_REPAIR_ON_MONITOR_CHANGE:-false}" == true ]]; then watch_mutter & pids+=("$!"); fi
if [[ "${DISPLAY_REPAIR_ON_DRM_HOTPLUG:-false}" == true ]]; then watch_drm & pids+=("$!"); fi
(( ${#pids[@]} )) || exit 0
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
trap 'exit 0' INT TERM
wait -n "${pids[@]}"
