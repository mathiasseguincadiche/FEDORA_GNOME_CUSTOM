#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"
# shellcheck source=lib/persistent_data.sh
source "$REPO_ROOT/lib/persistent_data.sh"

include_vms=false
prune=false
while (($#)); do
  case "$1" in
    --include-vms) include_vms=true; shift ;;
    --prune) prune=true; shift ;;
    -h|--help)
      echo 'Usage: backup-now.sh [--include-vms] [--prune]'; echo '  --prune applies the versioned retention policy to full and daily snapshots, then runs restic prune.'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for cmd in restic jq git tar rpm; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd" >&2; exit 20; }; done
repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
password_file="$(backup_runtime_require_password)" || { echo 'Secure Restic password file is required.' >&2; exit 20; }
backup_runtime_export_env "$repo" "$password_file"
restic cat config >/dev/null || { echo 'Restic repository is not initialized/reachable.' >&2; exit 20; }

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$STATE_ROOT/backup-staging"
staging="$(mktemp -d "$STATE_ROOT/backup-staging/$stamp.XXXXXX")"
mkdir -p "$staging/inventory" "$staging/libvirt" "$staging/vm-disks"
trap 'rm -rf "$staging"' EXIT
backup_runtime_capture_inventory "$staging/inventory"
backup_runtime_export_libvirt "$staging/libvirt"
printf 'fedora-gnome-custom backup canary\ncommit=%s\n' "$(repo_commit)" > "$staging/restore-canary.txt"

sudo tar -C / --xattrs --acls --selinux --numeric-owner -czf "$staging/fedora-system-config.tar.gz" etc boot
sudo chown "$(id -u):$(id -g)" "$staging/fedora-system-config.tar.gz"

if $include_vms; then
  for cmd in virsh qemu-img python3; do command -v "$cmd" >/dev/null || { echo "Missing VM backup command: $cmd" >&2; exit 20; }; done
  uri="${LIBVIRT_URI:-qemu:///system}"
  domains="$(sudo virsh -c "$uri" list --all --name)"
  while IFS= read -r dom; do
    [[ -n "$dom" ]] || continue
    [[ "$dom" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Unsafe domain name' >&2; exit 30; }
    state="$(LC_ALL=C sudo virsh -c "$uri" domstate "$dom")"
    [[ "$state" == 'shut off' ]] || { echo "VM must be shut off before disk backup: $dom ($state)" >&2; exit 30; }
    backup_runtime_virsh_capture "$uri" "$staging/libvirt/domains/$dom.xml" dumpxml --inactive "$dom"
    plan="$staging/libvirt/domains/$dom-backup-plan.json"
    python3 "$REPO_ROOT/scripts/backup/vm-backup-plan.py" "$staging/libvirt/domains/$dom.xml" > "$plan"
    while IFS= read -r disk; do
      source="$(jq -r '.source' <<<"$disk")"; target="$(jq -r '.target' <<<"$disk")"
      out="$staging/vm-disks/${dom}-${target}.qcow2"
      sudo qemu-img check "$source"
      sudo qemu-img convert -O qcow2 "$source" "$out"
      sudo chown "$(id -u):$(id -g)" "$out"
      qemu-img check "$out"
    done < <(jq -c '.disks[]' "$plan")
    mapfile -t state_paths < <(jq -r '.state_paths[]' "$plan")
    if (( ${#state_paths[@]} )); then
      for state_path in "${state_paths[@]}"; do
        sudo test -e "$state_path" || { echo "Missing persistent VM state: $state_path" >&2; exit 30; }
      done
      # Absolute paths in the archive become relative to the recovery staging
      # root. Never extract this archive directly over a running libvirt host.
      sudo tar --xattrs --acls --selinux --numeric-owner -czf "$staging/libvirt/domains/$dom-persistent-state.tar.gz" -- "${state_paths[@]}"
      sudo chown "$(id -u):$(id -g)" "$staging/libvirt/domains/$dom-persistent-state.tar.gz"
    fi
    [[ "$(LC_ALL=C sudo virsh -c "$uri" domstate "$dom")" == 'shut off' ]] || { echo "VM started during backup: $dom" >&2; exit 30; }
  done <<< "$domains"
  if is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-true}" && [[ -d "${KVM_DATA_MOUNT:-/data}/libvirt/cloud-init" ]]; then
    sudo tar -C "${KVM_DATA_MOUNT:-/data}/libvirt" -czf "$staging/cloud-init-metadata.tar.gz" cloud-init
    sudo chown "$(id -u):$(id -g)" "$staging/cloud-init-metadata.tar.gz"
  fi
fi

sources=("$staging")
for user_path in .config .local/share .var/app .mozilla .ssh .gnupg; do
  [[ ! -d "$HOME/$user_path" ]] || sources+=("$HOME/$user_path")
done
if runtime_is_baremetal; then
  persistent_data_validate_mount || { echo 'Refusing full backup: /data is not the dedicated EXT4 second T705.' >&2; exit 20; }
  [[ -d "$(persistent_data_documents)" ]] && sources+=("$(persistent_data_documents)")
  [[ -d "$(persistent_data_projects)" ]] && sources+=("$(persistent_data_projects)")
fi
while IFS= read -r -d '' tracked; do sources+=("$REPO_ROOT/$tracked"); done < <(git -C "$REPO_ROOT" ls-files -z)
restic backup --tag fedora-gnome-custom-full --exclude "$HOME/.config/fedora-gnome-custom/secrets" "${sources[@]}"
snap="$(restic snapshots --tag fedora-gnome-custom-full --latest 1 --json | jq -r '.[0].id // empty')"
[[ "$snap" =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'Invalid snapshot id.' >&2; exit 40; }
restic check --read-data-subset=1/20

if $prune; then
  "$REPO_ROOT/scripts/backup/restic-retention.sh" --strict
fi
printf 'snapshot=%s\ncommit=%s\nutc=%s\ninclude_vms=%s\nintegrity_check=PASS\n' \
  "$snap" "$(repo_commit)" "$(date -u +%FT%TZ)" "$include_vms" > "$STATE_ROOT/last-full-backup.ok"
chmod 0600 "$STATE_ROOT/last-full-backup.ok"
printf 'Backup completed: %s\n' "$snap"
