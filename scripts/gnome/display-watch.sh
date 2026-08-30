#!/usr/bin/env bash
set -Eeuo pipefail
repair="$HOME/.local/libexec/fedora-gnome-display-repair"
[[ -x "$repair" ]] || exit 0
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom"; mkdir -p "$state_dir"
trigger(){
  local reason="$1" lock="$state_dir/display-repair.lock"
  (
    flock -n 9 || exit 0
    sleep 1
    "$repair" >> "$state_dir/display-repair-watch.log" 2>&1 || true
    printf '%s reason=%s\n' "$(date -u +%FT%TZ)" "$reason" >> "$state_dir/display-repair-watch.log"
  ) 9>"$lock" &
}
watch_sleep(){
  gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *PrepareForSleep*false* ]] && trigger resume
  done
}
watch_mutter(){
  gdbus monitor --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *MonitorsChanged* ]] && trigger mutter-monitors-changed
  done
}
watch_drm(){
  udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *change*drm* ]] && trigger drm-hotplug
  done
}
watch_sleep & p1=$!; watch_mutter & p2=$!; watch_drm & p3=$!
trap 'kill "$p1" "$p2" "$p3" 2>/dev/null || true' EXIT INT TERM
wait -n "$p1" "$p2" "$p3"
