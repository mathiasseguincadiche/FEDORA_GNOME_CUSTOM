#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

for cmd in borg jq python3 sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing recovery command: $cmd" >&2; exit 20; }
done
backup_engine_require || exit 20
repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
backup_engine_env "$repo"
backup_engine_repo_ready || { echo 'Borg repository is not reachable (or is encrypted).' >&2; exit 20; }
read -r latest latest_id < <(backup_engine_latest full) || { echo 'No usable recovery archive.' >&2; exit 30; }
[[ "$latest_id" =~ ^[0-9a-f]{64}$ ]] || { echo 'No usable recovery archive.' >&2; exit 30; }

backup_engine_archive_matches "$latest" "$latest_id" full || exit 30
manifest="$(backup_runtime_recovery_manifest "$latest")" || { echo 'Full archive has no valid recovery manifest; create a new full backup.' >&2; exit 30; }
backup_engine_check full "$latest" || { echo 'Full recovery archive integrity check failed.' >&2; exit 30; }
backup_runtime_recovery_canary_valid "$latest" "$manifest" || { echo 'Recovery canary extraction failed or mismatched.' >&2; exit 30; }
recovery_commit="$(jq -r '.commit' <<<"$manifest")"
vm_coverage="$(jq -r 'if .include_vms then "requested; VM count=" + (.vm_count|tostring) else "NO VM DISKS; metadata only" end' <<<"$manifest")"

mkdir -p "$STATE_ROOT"
plan="$STATE_ROOT/disaster-recovery-$(date -u +%Y%m%dT%H%M%SZ).txt"
cat > "$plan" <<EOF
FEDORA_GNOME_CUSTOM — DISASTER RECOVERY PLAN
Generated: $(date -u +%FT%TZ)
Repository: $repo
Selected full archive: $latest ($latest_id)
Recovery commit: $recovery_commit
VM disk coverage: $vm_coverage
Newer daily archives contain user files and are not OS/VM recovery bases.
Engine: Borg 1.x, unencrypted repository (ADR 0014)

1. Install the selected promoted Fedora Workstation profile and matching GNOME/Wayland, SELinux Enforcing and firewalld.
2. Recreate the manual /data EXT4 mount on the dedicated VM SSD; do not let project automation format disks.
3. Clone FEDORA_GNOME_CUSTOM and checkout the commit associated with the chosen backup when available.
4. Run ./diagnostic.sh and ./install.sh --dry-run before any real convergence.
5. Install borgbackup, then restore the selected Borg archive into a staging directory with scripts/backup/restore.sh (no passphrase is needed).
6. Review fedora-system-config.tar.gz, inventory/ and libvirt XML before applying anything manually.
7. Recreate libvirt network/pool definitions from reviewed XML; never overwrite conflicting live definitions blindly.
8. Restore qcow2 images only while the affected VM is undefined/shut off, then run qemu-img check and restorecon.
9. Recover the matching NVRAM and swtpm archive with the original domain UUID, ownership and SELinux labels; boot an isolated recovery VM before declaring recovery successful. Recreate cloud-init/Windows media as needed; proprietary ISO files are not assumed to be backed up.
10. Run diagnostics/gnome-doctor, diagnostics/virtualization-doctor, diagnostics/backup-doctor and KVM runtime certification.
11. Only after all postchecks pass, resume normal workstation use.

This helper is intentionally non-destructive. It never formats storage, overwrites /etc, replaces active VM disks or redefines libvirt objects automatically.
EOF
printf 'Recovery repository verified. Plan written to: %s\n' "$plan"
