#!/usr/bin/env bash
set -Eeuo pipefail
backup_inventory_precheck() { [[ -r "$REPO_ROOT/scripts/backup/backup-now.sh" ]]; }
backup_inventory_plan() {
  cat <<'EOF'
PROTECTED ASSET INVENTORY:
- RPM/Flatpak inventory, enabled systemd units, storage, mounts, PCI and routing state
- tracked project source/config/manifests/docs required to rebuild the workstation
- privileged Fedora configuration from /etc and /boot captured into a metadata-preserving archive
- libvirt domain/network/pool XML exported before backup
- VM qcow2 and cloud-init media are catalogued separately from host configuration
EOF
}
backup_inventory_apply() { :; }
backup_inventory_postcheck() { [[ -r "$REPO_ROOT/scripts/backup/backup-now.sh" ]]; }
