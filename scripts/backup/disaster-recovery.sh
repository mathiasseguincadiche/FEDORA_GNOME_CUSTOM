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
vm_coverage="$(jq -r 'if .include_vms then "UNSUPPORTED ARCHIVE; VM exports are owner-managed" else "NONE; VM exports are manual and separate from Borg" end' <<<"$manifest")"

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
2. Recreate the manual /data EXT4 mount on the dedicated second T705 and re-enroll its identity; do not let project automation format disks.
3. Clone FEDORA_GNOME_CUSTOM and checkout the commit associated with the chosen backup when available.
4. Run ./diagnostic.sh and ./install.sh --dry-run before any real convergence.
5. Install borgbackup, then restore the selected Borg archive into a staging directory with scripts/backup/restore.sh (no passphrase is needed).
6. Review fedora-system-config.tar.gz and inventory/ before applying anything manually.
7. Recreate host networking/KVM tooling with the project; no VM domain or disk export is included in Borg.
8. If virtual machines must be recovered, use the owner's SEPARATE MANUAL exports of their disks/XML/NVRAM/TPM. Do not infer VM coverage from this Borg archive.
9. Restore the owner's manual VM exports only after reviewing their authenticity, UUIDs, permissions and SELinux labels; boot an isolated recovery VM before use.
10. Run diagnostics/gnome-doctor, diagnostics/virtualization-doctor and diagnostics/backup-doctor on the rebuilt host.
11. Resume normal workstation use only after all independent host and manual VM checks pass.

This helper is intentionally non-destructive. It never formats storage, overwrites /etc, replaces active VM disks or redefines libvirt objects automatically.
EOF
printf 'Recovery repository verified. Plan written to: %s\n' "$plan"
