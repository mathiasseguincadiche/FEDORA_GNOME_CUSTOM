#!/usr/bin/env bash
set -Eeuo pipefail

gnome_nautilus_precheck() { command_exists dnf; }
gnome_nautilus_plan() { echo 'Converge Nautilus local/remote integration and optimize true first-click cold start by prewarming only portals/GIO, never Nautilus itself.'; }
gnome_nautilus_apply() {
  run_mutating GNOME sudo dnf -y install nautilus gvfs gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse
  if is_true "${REMOVE_IBUS_TYPING_BOOSTER:-true}" && rpm -q ibus-typing-booster >/dev/null 2>&1; then
    run_mutating GNOME sudo dnf -y remove ibus-typing-booster
  fi
  if ! is_true "${DRY_RUN:-true}"; then
    install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
    install -m 0755 "$REPO_ROOT/scripts/gnome/nautilus-prewarm.sh" "$HOME/.local/libexec/fedora-gnome-nautilus-prewarm"
    install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-nautilus-prewarm.service" "$HOME/.config/systemd/user/fedora-gnome-nautilus-prewarm.service"
    if command_exists gsettings && gsettings list-schemas | grep -Fxq org.gnome.nautilus.preferences; then
      gsettings set org.gnome.nautilus.preferences show-image-thumbnails "'${NAUTILUS_PREVIEW_POLICY:-local-only}'" || true
    fi
    systemctl --user daemon-reload
    systemctl --user enable fedora-gnome-nautilus-prewarm.service
  fi
}
gnome_nautilus_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  rpm -q nautilus gvfs gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  [[ -x "$HOME/.local/libexec/fedora-gnome-nautilus-prewarm" ]] || return "$EXIT_POSTCHECK_FAILED"
  systemctl --user is-enabled --quiet fedora-gnome-nautilus-prewarm.service || return "$EXIT_POSTCHECK_FAILED"
}
