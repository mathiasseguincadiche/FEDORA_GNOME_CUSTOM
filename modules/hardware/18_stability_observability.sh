#!/usr/bin/env bash
set -Eeuo pipefail
hardware_observability_precheck() { [[ -r "$REPO_ROOT/systemd/fedora-gnome-custom-boot-health.service" && -r "$REPO_ROOT/systemd/fedora-gnome-custom-resume-health.service" ]]; }
hardware_observability_plan() { echo 'Enable bounded persistent journald/coredump evidence plus boot/resume health capture. Do not auto-enable kdump or a hardware watchdog.'; }
hardware_observability_apply() {
  run_mutating HARDWARE sudo install -D -m 0644 "$REPO_ROOT/systemd/journald-80-fedora-gnome-custom.conf" /etc/systemd/journald.conf.d/80-fedora-gnome-custom.conf
  run_mutating HARDWARE sudo install -D -m 0644 "$REPO_ROOT/systemd/coredump-80-fedora-gnome-custom.conf" /etc/systemd/coredump.conf.d/80-fedora-gnome-custom.conf
  run_mutating HARDWARE sudo install -D -m 0755 "$REPO_ROOT/scripts/systemd/fedora-custom-boot-health" /usr/local/libexec/fedora-custom-boot-health
  run_mutating HARDWARE sudo install -D -m 0755 "$REPO_ROOT/scripts/systemd/fedora-custom-resume-health" /usr/local/libexec/fedora-custom-resume-health
  run_mutating HARDWARE sudo install -D -m 0644 "$REPO_ROOT/systemd/fedora-gnome-custom-boot-health.service" /etc/systemd/system/fedora-gnome-custom-boot-health.service
  run_mutating HARDWARE sudo install -D -m 0644 "$REPO_ROOT/systemd/fedora-gnome-custom-resume-health.service" /etc/systemd/system/fedora-gnome-custom-resume-health.service
  run_mutating HARDWARE sudo install -d -m 0755 /var/lib/fedora-gnome-custom/health
  run_mutating HARDWARE sudo systemctl daemon-reload
  run_mutating HARDWARE sudo systemctl enable --now fedora-gnome-custom-boot-health.service
  run_mutating HARDWARE sudo systemctl restart systemd-journald.service
}
hardware_observability_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  [[ -r /etc/systemd/journald.conf.d/80-fedora-gnome-custom.conf ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ -r /etc/systemd/coredump.conf.d/80-fedora-gnome-custom.conf ]] || return "$EXIT_POSTCHECK_FAILED"
  systemctl is-enabled fedora-gnome-custom-boot-health.service >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
