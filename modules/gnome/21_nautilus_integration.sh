#!/usr/bin/env bash
set -Eeuo pipefail
gnome_nautilus_precheck() { command_exists dnf; }
gnome_nautilus_plan() { echo 'Converge Nautilus local/remote integration: archives, SMB, MTP, camera, FUSE, Sushi preview and Open in Terminal.'; }
gnome_nautilus_apply() { run_mutating GNOME sudo dnf -y install nautilus file-roller gvfs gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse sushi gnome-terminal-nautilus; }
gnome_nautilus_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  rpm -q nautilus file-roller gvfs-smb gvfs-mtp sushi gnome-terminal-nautilus >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
