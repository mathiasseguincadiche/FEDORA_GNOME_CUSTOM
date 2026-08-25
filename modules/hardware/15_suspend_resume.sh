#!/usr/bin/env bash
set -Eeuo pipefail
hardware_suspend_precheck() { [[ -r "$REPO_ROOT/scripts/systemd/fedora-custom-sleep-hook" ]]; }
hardware_suspend_plan() { echo 'Install a minimal system-sleep hook that only records phase/timestamps and queues post-resume health capture; heavy diagnostics stay outside the suspend critical path.'; }
hardware_suspend_apply() {
  run_mutating HARDWARE sudo install -D -m 0755 "$REPO_ROOT/scripts/systemd/fedora-custom-sleep-hook" /usr/lib/systemd/system-sleep/fedora-gnome-custom
  run_mutating HARDWARE sudo install -d -m 0755 /var/lib/fedora-gnome-custom/suspend
}
hardware_suspend_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  [[ -x /usr/lib/systemd/system-sleep/fedora-gnome-custom ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ -r /sys/power/mem_sleep ]] && log_info HARDWARE "mem_sleep=$(< /sys/power/mem_sleep)"
}
