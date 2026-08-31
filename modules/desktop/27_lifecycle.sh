#!/usr/bin/env bash
set -Eeuo pipefail

desktop_lifecycle_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  [[ "${LIFECYCLE_FLATPAK_UPDATE_POLICY:-manual}" == manual ]] || { log_error DESKTOP 'Only manual Flatpak application updates are supported by the Golden Workstation policy'; return "$EXIT_CONFIG_FAILED"; }
}

desktop_lifecycle_plan() { echo 'Enable safe lifecycle automation: download Fedora RPM updates automatically, never install/reboot unattended; Flatpak application updates remain explicit/manual; keep fstrim and fwupd metadata refresh active.'; }

desktop_lifecycle_apply() {
  local tmp
  run_mutating DESKTOP sudo dnf -y install dnf5-plugin-automatic dnf5-plugins || return "$EXIT_APPLY_FAILED"
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
[commands]
upgrade_type = default
download_updates = ${LIFECYCLE_AUTOMATIC_DOWNLOADS:-true}
apply_updates = ${LIFECYCLE_AUTOMATIC_INSTALLS:-false}
reboot = ${LIFECYCLE_AUTOMATIC_REBOOT:-never}

[emitters]
emit_via = motd
emit_no_updates = false
EOF
  run_mutating DESKTOP sudo install -m 0644 "$tmp" /etc/dnf/automatic.conf || { rm -f "$tmp"; return "$EXIT_APPLY_FAILED"; }
  rm -f "$tmp"
  run_mutating DESKTOP sudo systemctl enable --now dnf5-automatic.timer || return "$EXIT_APPLY_FAILED"
  if is_true "${LIFECYCLE_ENABLE_FSTRIM:-true}"; then run_mutating DESKTOP sudo systemctl enable --now fstrim.timer || return "$EXIT_APPLY_FAILED"; fi
  if is_true "${LIFECYCLE_ENABLE_FWUPD_REFRESH:-true}" && systemctl list-unit-files fwupd-refresh.timer --no-legend 2>/dev/null | grep -q '^fwupd-refresh.timer'; then run_mutating DESKTOP sudo systemctl enable --now fwupd-refresh.timer || return "$EXIT_APPLY_FAILED"; fi
}

desktop_lifecycle_postcheck() { is_true "${DRY_RUN:-true}" && return 0; "$REPO_ROOT/diagnostics/lifecycle-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"; }
