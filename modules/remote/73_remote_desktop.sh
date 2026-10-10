#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/remote_access.sh"

remote_desktop_precheck() {
  remote_enabled || return 0
  if remote_sunshine_enabled; then
    command_exists dnf || { log_error REMOTE 'dnf is required'; return "$EXIT_PRECHECK_FAILED"; }
    [[ -r "$REPO_ROOT/manifests/packages-remote-sunshine.txt" ]] || { log_error REMOTE 'missing Sunshine manifest'; return "$EXIT_PRECHECK_FAILED"; }
  fi
  if remote_autologin_enabled; then
    [[ -r "$REPO_ROOT/scripts/remote/gdm_autologin.py" ]] || { log_error REMOTE 'missing GDM autologin helper'; return "$EXIT_PRECHECK_FAILED"; }
    [[ "$(remote_user)" != root ]] || { log_error REMOTE 'automatic login of root is refused'; return "$EXIT_PRECHECK_FAILED"; }
  fi
}

remote_desktop_plan() {
  if remote_enabled; then
    echo 'Optionally install Sunshine from the LizardByte COPR and enable its user service, optionally configure GDM automatic login with an immediate session lock, and optionally allow passwordless poweroff for the workstation user. Each step is an explicit REMOTE_* opt-in.'
  else
    echo 'Remote-access profile disabled: Sunshine, GDM automatic login and polkit untouched.'
  fi
}

remote_desktop_sunshine() {
  local marker conf
  marker="$(remote_state_dir)/sunshine-managed"
  conf="$HOME/.config/sunshine/sunshine.conf"
  if remote_sunshine_enabled; then
    run_mutating REMOTE sudo dnf -y copr enable "${REMOTE_SUNSHINE_COPR:-lizardbyte/stable}" || return "$EXIT_APPLY_FAILED"
    install_manifest_packages REMOTE "$REPO_ROOT/manifests/packages-remote-sunshine.txt" || return "$EXIT_APPLY_FAILED"
    # Security default upstream is LAN. Restrict the administration Web UI to localhost.
    run_mutating REMOTE python3 "$REPO_ROOT/scripts/remote/sunshine-config.py" "$conf" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE systemctl --user enable sunshine.service || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE sudo install -d -m 0755 "$(remote_state_dir)" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE sudo touch "$marker" || return "$EXIT_APPLY_FAILED"
  elif [[ -e "$marker" ]]; then
    # Only disable a Sunshine service previously enabled through our profile.
    run_mutating REMOTE systemctl --user disable --now sunshine.service || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE sudo rm -f "$marker" || return "$EXIT_APPLY_FAILED"
  fi
}

remote_desktop_autologin() {
  local user marker conf state lock_unit lock_bin
  user="$(remote_user)"
  marker="$(remote_state_dir)/autologin-managed"
  conf="${REMOTE_GDM_CONF:-/etc/gdm/custom.conf}"
  lock_unit="$HOME/.config/systemd/user/fgc-remote-lock.service"
  lock_bin="$HOME/.local/libexec/fgc-remote-lock"
  if remote_autologin_enabled; then
    run_mutating REMOTE sudo install -d -m 0755 "$(remote_state_dir)" || return "$EXIT_APPLY_FAILED"
    if ! sudo test -e "$marker"; then
      run_mutating REMOTE sudo cp -n "$conf" "$conf.fgc-backup" || return "$EXIT_APPLY_FAILED"
    fi
    run_mutating REMOTE sudo python3 "$REPO_ROOT/scripts/remote/gdm_autologin.py" enable --user "$user" --file "$conf" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE sudo touch "$marker" || return "$EXIT_APPLY_FAILED"
  elif sudo test -e "$marker"; then
    state="$(remote_autologin_status)"
    if [[ "$state" == "enabled user=$user" ]]; then
      run_mutating REMOTE sudo python3 "$REPO_ROOT/scripts/remote/gdm_autologin.py" disable --file "$conf" --restore-from "$conf.fgc-backup" || return "$EXIT_APPLY_FAILED"
    elif [[ "$state" == enabled* ]]; then
      log_error REMOTE 'GDM was changed to a different user: refusing to change manually managed autologin'
      return "$EXIT_APPLY_FAILED"
    fi
    run_mutating REMOTE sudo rm -f "$marker" || return "$EXIT_APPLY_FAILED"
  fi
  if remote_autologin_enabled && is_true "${REMOTE_LOCK_ON_AUTOLOGIN:-true}"; then
    run_mutating REMOTE install -Dm0755 "$REPO_ROOT/scripts/remote/lock-graphical-session.sh" "$lock_bin" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE install -Dm0644 "$REPO_ROOT/remote/systemd/user/fgc-remote-lock.service" "$lock_unit" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE systemctl --user daemon-reload || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE systemctl --user enable fgc-remote-lock.service || return "$EXIT_APPLY_FAILED"
  elif [[ -f "$lock_unit" ]]; then
    run_mutating REMOTE systemctl --user disable --now fgc-remote-lock.service || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE rm -f "$lock_unit" "$lock_bin" || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE systemctl --user daemon-reload || return "$EXIT_APPLY_FAILED"
  fi
}

remote_desktop_poweroff() {
  local rule user tmp
  rule="$(remote_polkit_rule)"
  user="$(remote_user)"
  if is_true "${REMOTE_POWEROFF_POLKIT:-false}"; then
    tmp="$(mktemp)" || return "$EXIT_APPLY_FAILED"
    remote_render_template "$REPO_ROOT/remote/polkit/50-fgc-remote-power.rules.in" "$user" > "$tmp"
    run_mutating REMOTE sudo install -Dm0644 "$tmp" "$rule" || { rm -f "$tmp"; return "$EXIT_APPLY_FAILED"; }
    rm -f "$tmp"
  elif [[ -e "$rule" ]]; then
    run_mutating REMOTE sudo rm -f "$rule" || return "$EXIT_APPLY_FAILED"
  fi
}

remote_desktop_apply() {
  remote_enabled || return 0
  remote_desktop_sunshine || return $?
  remote_desktop_autologin || return $?
  remote_desktop_poweroff || return $?
}

remote_desktop_postcheck() {
  remote_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0
  if remote_sunshine_enabled; then
    rpm -q Sunshine >/dev/null 2>&1 || { log_error REMOTE 'Sunshine package missing'; return "$EXIT_POSTCHECK_FAILED"; }
    python3 "$REPO_ROOT/scripts/remote/sunshine-config.py" --check "$HOME/.config/sunshine/sunshine.conf" ||
      { log_error REMOTE 'Sunshine web UI is not restricted to localhost'; return "$EXIT_POSTCHECK_FAILED"; }
  fi
  if remote_autologin_enabled; then
    [[ "$(remote_autologin_status)" == "enabled user=$(remote_user)" ]] || { log_error REMOTE 'GDM automatic login is not configured for the workstation user'; return "$EXIT_POSTCHECK_FAILED"; }
  fi
}
