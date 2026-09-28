#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/install_lock.sh"
install_lock_acquire || exit $?
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
      echo 'Usage: backup-now.sh [--include-vms] [--prune]'; echo '  --prune applies the versioned retention policy to full and daily archives, then compacts the Borg repository.'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for cmd in borg jq git tar rpm; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd" >&2; exit 20; }; done
backup_engine_require || exit 20
repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
backup_engine_env "$repo"
backup_engine_repo_ready || { echo 'Borg repository is not initialized/reachable, or is encrypted (policy: unencrypted).' >&2; exit 20; }

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
read -r archive snap < <(backup_engine_create full --exclude "$HOME/.config/fedora-gnome-custom/secrets" -- "${sources[@]}") || { echo 'Borg archive creation failed.' >&2; exit 40; }
[[ "$snap" =~ ^[0-9a-f]{64}$ && -n "$archive" ]] || { echo 'Invalid archive id.' >&2; exit 40; }
backup_engine_check full || { echo 'Borg integrity check failed.' >&2; exit 40; }

if $prune; then
  "$REPO_ROOT/scripts/backup/backup-retention.sh" --strict
fi
printf 'snapshot=%s\narchive=%s\ncommit=%s\nutc=%s\ninclude_vms=%s\nintegrity_check=PASS\n' \
  "$snap" "$archive" "$(repo_commit)" "$(date -u +%FT%TZ)" "$include_vms" > "$STATE_ROOT/last-full-backup.ok"
chmod 0600 "$STATE_ROOT/last-full-backup.ok"
printf 'Backup completed: %s (%s)\n' "$archive" "$snap"
