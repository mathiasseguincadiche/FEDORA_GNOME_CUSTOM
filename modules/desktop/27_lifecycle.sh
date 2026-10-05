#!/usr/bin/env bash
set -Eeuo pipefail

desktop_lifecycle_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  [[ "${LIFECYCLE_AUTOMATIC_INSTALLS:-false}" == false && "${LIFECYCLE_AUTOMATIC_REBOOT:-never}" == never ]] || return "$EXIT_CONFIG_FAILED"
  [[ "${LIFECYCLE_FLATPAK_UPDATE_POLICY:-manual}" == manual ]] || { log_error DESKTOP 'Only manual Flatpak application updates are supported by the Golden Workstation policy'; return "$EXIT_CONFIG_FAILED"; }
}

desktop_lifecycle_plan() { echo 'Enable safe lifecycle automation: download Fedora RPM updates automatically, never install/reboot unattended; Flatpak application updates remain explicit/manual; keep fstrim and fwupd metadata refresh active.'; }

desktop_lifecycle_apply() {
  local tmp profile
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
  # GNOME Software remains a catalogue/installer; system upgrades use control.sh.
  # Locks also prevent a user preference from silently re-enabling background installs.
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/locks"
  printf '[org/gnome/software]\ndownload-updates=false\nallow-updates=false\n' > "$tmp/00-updates"
  printf '/org/gnome/software/download-updates\n/org/gnome/software/allow-updates\n' > "$tmp/locks/updates"
  profile=/etc/dconf/profile/user
  if [[ -r "$profile" ]]; then cat "$profile" > "$tmp/profile"; else printf 'user-db:user\n' > "$tmp/profile"; fi
  if ! grep -Fxq 'system-db:fgc' "$tmp/profile"; then printf 'system-db:fgc\n' >> "$tmp/profile"; fi
  run_mutating DESKTOP sudo install -d -m 0755 /etc/dconf/profile /etc/dconf/db/fgc.d/locks || { rm -rf "$tmp"; return "$EXIT_APPLY_FAILED"; }
  run_mutating DESKTOP sudo install -m 0644 "$tmp/00-updates" /etc/dconf/db/fgc.d/00-updates || { rm -rf "$tmp"; return "$EXIT_APPLY_FAILED"; }
  run_mutating DESKTOP sudo install -m 0644 "$tmp/locks/updates" /etc/dconf/db/fgc.d/locks/updates || { rm -rf "$tmp"; return "$EXIT_APPLY_FAILED"; }
  run_mutating DESKTOP sudo install -m 0644 "$tmp/profile" "$profile" || { rm -rf "$tmp"; return "$EXIT_APPLY_FAILED"; }
  rm -rf "$tmp"
  run_mutating DESKTOP sudo dconf update || return "$EXIT_APPLY_FAILED"
  run_mutating DESKTOP sudo systemctl enable --now dnf5-automatic.timer || return "$EXIT_APPLY_FAILED"
  if is_true "${LIFECYCLE_ENABLE_FSTRIM:-true}"; then run_mutating DESKTOP sudo systemctl enable --now fstrim.timer || return "$EXIT_APPLY_FAILED"; fi
  if is_true "${LIFECYCLE_ENABLE_FWUPD_REFRESH:-true}" && systemctl list-unit-files fwupd-refresh.timer --no-legend 2>/dev/null | grep -q '^fwupd-refresh.timer'; then run_mutating DESKTOP sudo systemctl enable --now fwupd-refresh.timer || return "$EXIT_APPLY_FAILED"; fi
}

desktop_lifecycle_postcheck() { is_true "${DRY_RUN:-true}" && return 0; "$REPO_ROOT/diagnostics/lifecycle-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"; }
