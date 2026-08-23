#!/usr/bin/env bash
set -Eeuo pipefail

gnome_nautilus_precheck() { command_exists dnf; }
gnome_nautilus_plan() { echo 'Converge Nautilus local/remote integration: SMB, MTP, camera and FUSE. Desktop applications and terminal integration are managed by the APPLICATIONS scope.'; }
gnome_nautilus_apply() { run_mutating GNOME sudo dnf -y install nautilus gvfs gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse; }
gnome_nautilus_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  rpm -q nautilus gvfs gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
