#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
password_file="$(backup_runtime_require_password)" || { echo 'Secure Restic password file is required.' >&2; exit 20; }
backup_runtime_export_env "$repo" "$password_file"
restic cat config >/dev/null || { echo 'Restic repository is not reachable.' >&2; exit 20; }
latest="$(restic snapshots --latest 1 --json | jq -r '.[0].id // empty')"
[[ "$latest" =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'No usable recovery snapshot.' >&2; exit 30; }

mkdir -p "$STATE_ROOT"
plan="$STATE_ROOT/disaster-recovery-$(date -u +%Y%m%dT%H%M%SZ).txt"
cat > "$plan" <<EOF
FEDORA_GNOME_CUSTOM — DISASTER RECOVERY PLAN
Generated: $(date -u +%FT%TZ)
Repository: $repo
Latest snapshot: $latest

1. Install Fedora 44 Workstation and keep GNOME 50/Wayland, SELinux Enforcing and firewalld.
2. Recreate the manual /data EXT4 mount on the dedicated VM SSD; do not let project automation format disks.
3. Clone FEDORA_GNOME_CUSTOM and checkout the commit associated with the chosen backup when available.
4. Run ./diagnostic.sh and ./install.sh --dry-run before any real convergence.
5. Restore the selected Restic snapshot into a staging directory with scripts/backup/restore.sh.
6. Review fedora-system-config.tar.gz, inventory/ and libvirt XML before applying anything manually.
7. Recreate libvirt network/pool definitions from reviewed XML; never overwrite conflicting live definitions blindly.
8. Restore qcow2 images only while the affected VM is undefined/shut off, then run qemu-img check and restorecon.
9. Recreate cloud-init/Windows media as needed; proprietary ISO files are not assumed to be backed up.
10. Run diagnostics/gnome-doctor, diagnostics/virtualization-doctor, diagnostics/backup-doctor and KVM runtime certification.
11. Only after all postchecks pass, resume normal workstation use.

This helper is intentionally non-destructive. It never formats storage, overwrites /etc, replaces active VM disks or redefines libvirt objects automatically.
EOF
restic check --read-data-subset=1/50 >/dev/null
printf 'Recovery repository verified. Plan written to: %s\n' "$plan"
