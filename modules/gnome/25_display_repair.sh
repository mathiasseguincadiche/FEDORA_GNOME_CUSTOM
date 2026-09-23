#!/usr/bin/env bash
set -Eeuo pipefail

gnome_display_repair_precheck() { is_true "${DISPLAY_REPAIR_ENABLED:-true}" || return 0; [[ -r "$REPO_ROOT/scripts/gnome/display-repair.sh" && -r "$REPO_ROOT/scripts/gnome/display-watch.sh" ]]; }
gnome_display_repair_plan() { echo 'Install GNOME/Wayland display recovery: preserve the complete pre-suspend layout, scale and HDR; observe monitor/hotplug changes without overwriting user settings.'; }
gnome_display_repair_apply() {
  if ! is_true "${DISPLAY_REPAIR_ENABLED:-true}"; then
    is_true "${DRY_RUN:-true}" || systemctl --user disable --now fedora-gnome-display-watch.service
    return 0
  fi
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  command_exists gdctl || { log_error GNOME 'gdctl is required for display recovery'; return "$EXIT_APPLY_FAILED"; }
  install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
  install -m 0755 "$REPO_ROOT/scripts/gnome/display-repair.sh" "$HOME/.local/libexec/fedora-gnome-display-repair"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom" var policy_tmp
  install -d -m 0700 "$state_dir"
  policy_tmp="$(mktemp "$state_dir/.display-policy.XXXXXX")"
  while IFS= read -r var; do printf '%s=%q\n' "$var" "${!var}" >> "$policy_tmp"; done < <(compgen -v DISPLAY_)
  mv -f "$policy_tmp" "$state_dir/display-policy.env"
  install -m 0755 "$REPO_ROOT/scripts/gnome/display-state.py" "$HOME/.local/libexec/fedora-gnome-display-state.py"
  install -m 0755 "$REPO_ROOT/scripts/gnome/display-watch.sh" "$HOME/.local/libexec/fedora-gnome-display-watch"
  install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-display-watch.service" "$HOME/.config/systemd/user/fedora-gnome-display-watch.service"
  systemctl --user daemon-reload
  systemctl --user enable fedora-gnome-display-watch.service
  systemctl --user restart fedora-gnome-display-watch.service
  "$HOME/.local/libexec/fedora-gnome-display-repair" || log_warn GNOME 'initial display repair deferred; rerun inside an active GNOME Wayland session'
}
gnome_display_repair_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${DISPLAY_REPAIR_ENABLED:-true}" || return 0
  [[ -x "$HOME/.local/libexec/fedora-gnome-display-repair" && -x "$HOME/.local/libexec/fedora-gnome-display-watch" ]] || return "$EXIT_POSTCHECK_FAILED"
  systemctl --user is-enabled --quiet fedora-gnome-display-watch.service || return "$EXIT_POSTCHECK_FAILED"
}
