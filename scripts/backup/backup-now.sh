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
staging_root="$STATE_ROOT/backup-staging"
while (($#)); do
  case "$1" in
    --include-vms) include_vms=true; shift ;;
    --prune) prune=true; shift ;;
    --staging-root) [[ ${2:-} == /* ]] || { echo '--staging-root requires an absolute path' >&2; exit 2; }; staging_root="$2"; shift 2 ;;
    -h|--help)
      echo 'Usage: backup-now.sh [--include-vms] [--prune] [--staging-root /absolute/path]'; echo '  --prune applies the versioned retention policy to full and daily archives, then compacts the Borg repository.'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for cmd in borg jq git tar rpm; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing command: $cmd" >&2; exit 20; }; done
backup_engine_require || exit 20
repo="$(backup_runtime_resolve_repository)" || { echo 'Cannot resolve backup repository.' >&2; exit 20; }
backup_engine_env "$repo"
backup_engine_repo_ready || { echo 'Borg repository is not initialized/reachable, or is encrypted (policy: unencrypted).' >&2; exit 20; }

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$staging_root"
staging_root="$(readlink -f -- "$staging_root")"
staging="$(mktemp -d "$staging_root/$stamp.XXXXXX")"
mkdir -p "$staging/inventory" "$staging/libvirt" "$staging/vm-disks"
trap 'rm -rf "$staging"' EXIT
backup_runtime_capture_inventory "$staging/inventory"
backup_runtime_export_libvirt "$staging/libvirt"
printf 'fedora-gnome-custom backup canary\ncommit=%s\n' "$(repo_commit)" > "$staging/restore-canary.txt"

system_bytes="$(sudo du -scB1 /etc /boot | awk 'END {print $1}')"
backup_runtime_require_staging_space "$staging" "$system_bytes" || { echo 'Insufficient staging capacity for system configuration.' >&2; exit 40; }
sudo tar -C / --xattrs --acls --selinux --numeric-owner -czf "$staging/fedora-system-config.tar.gz" etc boot
sudo chown "$(id -u):$(id -g)" "$staging/fedora-system-config.tar.gz"

vm_count=0
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
    ((vm_count+=1))
    plan="$staging/libvirt/domains/$dom-backup-plan.json"
    python3 "$REPO_ROOT/scripts/backup/vm-backup-plan.py" "$staging/libvirt/domains/$dom.xml" > "$plan"
    while IFS= read -r disk; do
      source="$(jq -r '.source' <<<"$disk")"; target="$(jq -r '.target' <<<"$disk")"
      out="$staging/vm-disks/${dom}-${target}.qcow2"
      sudo qemu-img check "$source"
      required="$(sudo qemu-img measure --output=json -O qcow2 "$source" | jq -er '.required')"
      backup_runtime_require_staging_space "$staging" "$required" || { echo "Insufficient staging capacity for VM $dom disk $target." >&2; exit 40; }
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
      required="$(sudo du -scB1 -- "${state_paths[@]}" | awk 'END {print $1}')"
      backup_runtime_require_staging_space "$staging" "$required" || { echo "Insufficient staging capacity for VM $dom persistent state." >&2; exit 40; }
      sudo tar --xattrs --acls --selinux --numeric-owner -czf "$staging/libvirt/domains/$dom-persistent-state.tar.gz" -- "${state_paths[@]}"
      sudo chown "$(id -u):$(id -g)" "$staging/libvirt/domains/$dom-persistent-state.tar.gz"
    fi
    [[ "$(LC_ALL=C sudo virsh -c "$uri" domstate "$dom")" == 'shut off' ]] || { echo "VM started during backup: $dom" >&2; exit 30; }
  done <<< "$domains"
  if is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-true}" && [[ -d "${KVM_DATA_MOUNT:-/data}/libvirt/cloud-init" ]]; then
    required="$(sudo du -scB1 -- "${KVM_DATA_MOUNT:-/data}/libvirt/cloud-init" | awk 'END {print $1}')"
    backup_runtime_require_staging_space "$staging" "$required" || { echo 'Insufficient staging capacity for cloud-init metadata.' >&2; exit 40; }
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
backup_runtime_require_source_capacity "$repo" "${sources[@]}" || { echo 'Insufficient repository capacity for full backup.' >&2; exit 40; }
manifest="$(jq -cn --arg commit "$(repo_commit)" --arg config "$(effective_config_sha256)" --arg plan "$(module_plan_sha256)" \
  --arg hardware "$(evidence_hardware_fingerprint)" --arg canary "${staging#/}/restore-canary.txt" \
  --arg digest "$(sha256sum "$staging/restore-canary.txt" | awk '{print $1}')" --argjson vms "$include_vms" --argjson count "$vm_count" \
  '{schema:1,kind:"full",engine:"borg",encryption:"none",commit:$commit,effective_config_sha256:$config,module_plan_sha256:$plan,hardware_fingerprint:$hardware,canary_path:$canary,canary_sha256:$digest,include_vms:$vms,vm_count:$count}')"
printf '%s\n' "$manifest" > "$staging/recovery-manifest.json"
read -r archive snap < <(backup_engine_create full --comment "$manifest" --exclude "$HOME/.config/fedora-gnome-custom/secrets" -- "${sources[@]}") || { echo 'Borg archive creation failed.' >&2; exit 40; }
[[ "$snap" =~ ^[0-9a-f]{64}$ && -n "$archive" ]] || { echo 'Invalid archive id.' >&2; exit 40; }
backup_engine_check full "$archive" || { echo 'Borg integrity check failed.' >&2; exit 40; }

if $prune; then
  "$REPO_ROOT/scripts/backup/backup-retention.sh" --strict
fi
restore_test="$(mktemp -d "$staging/restore-proof.XXXXXX")"
backup_engine_extract "$archive" "$restore_test" "$staging/restore-canary.txt" || exit 40
cmp -s "$staging/restore-canary.txt" "$restore_test/${staging#/}/restore-canary.txt" || { echo 'Full backup restore canary mismatch.' >&2; exit 40; }
marker="$STATE_ROOT/last-full-backup.ok"
{
  printf 'verdict=PASS\nengine=borg\nencryption=none\nintegrity_check=PASS\nrestore_test=PASS\n'
  printf 'snapshot=%s\narchive=%s\nrepository=%s\ncommit=%s\nutc=%s\ninclude_vms=%s\nvm_count=%s\n' \
    "$snap" "$archive" "$repo" "$(repo_commit)" "$(date -u +%FT%TZ)" "$include_vms" "$vm_count"
  printf 'effective_config_sha256=%s\nmodule_plan_sha256=%s\nhardware_fingerprint=%s\n' \
    "$(effective_config_sha256)" "$(module_plan_sha256)" "$(evidence_hardware_fingerprint)"
} | evidence_atomic_write "$marker" 0600
if ! backup_runtime_validate_full_marker "$marker"; then
  rm -f "$marker"
  echo 'Full backup evidence validation failed.' >&2
  exit 40
fi
printf 'Backup completed: %s (%s)\n' "$archive" "$snap"
