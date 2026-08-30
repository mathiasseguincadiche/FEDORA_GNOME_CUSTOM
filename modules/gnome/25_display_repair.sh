#!/usr/bin/env bash
set -Eeuo pipefail

gnome_display_repair_precheck() { is_true "${DISPLAY_REPAIR_ENABLED:-true}" || return 0; [[ -r "$REPO_ROOT/scripts/gnome/display-repair.sh" && -r "$REPO_ROOT/scripts/gnome/display-watch.sh" ]]; }
gnome_display_repair_plan() { echo 'Install GNOME/Wayland display recovery: restore 1440p/240 Hz, scale 1.0, SDR/default and Full RGB after resume, Mutter monitor changes and DRM hotplug.'; }
gnome_display_repair_apply() {
  is_true "${DISPLAY_REPAIR_ENABLED:-true}" || return 0
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  command_exists gdctl || { log_error GNOME 'gdctl is required for display recovery'; return "$EXIT_APPLY_FAILED"; }
  install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
  install -m 0755 "$REPO_ROOT/scripts/gnome/display-repair.sh" "$HOME/.local/libexec/fedora-gnome-display-repair"
  install -m 0755 "$REPO_ROOT/scripts/gnome/display-watch.sh" "$HOME/.local/libexec/fedora-gnome-display-watch"
  install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-display-watch.service" "$HOME/.config/systemd/user/fedora-gnome-display-watch.service"
  systemctl --user daemon-reload
  systemctl --user enable --now fedora-gnome-display-watch.service
  "$HOME/.local/libexec/fedora-gnome-display-repair" || log_warn GNOME 'initial display repair deferred; rerun inside an active GNOME Wayland session'
}
gnome_display_repair_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${DISPLAY_REPAIR_ENABLED:-true}" || return 0
  [[ -x "$HOME/.local/libexec/fedora-gnome-display-repair" && -x "$HOME/.local/libexec/fedora-gnome-display-watch" ]] || return "$EXIT_POSTCHECK_FAILED"
  systemctl --user is-enabled --quiet fedora-gnome-display-watch.service || return "$EXIT_POSTCHECK_FAILED"
}
