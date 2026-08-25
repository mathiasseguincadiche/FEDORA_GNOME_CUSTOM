#!/usr/bin/env bash

backup_runtime_is_remote_repository() {
  local repo="$1"
  [[ "$repo" =~ ^(sftp:|rest:|rest\+|s3:|b2:|azure:|gs:|rclone:) ]]
}

backup_runtime_local_source_is_external() {
  local source="$1" name type tran rm hotplug
  source="$(readlink -f -- "$source" 2>/dev/null || true)"
  [[ -n "$source" && -b "$source" ]] || return 1
  while read -r name type tran rm hotplug; do
    [[ "$type" == disk ]] || continue
    if [[ "$tran" == usb || "$rm" == 1 || "$hotplug" == 1 ]]; then
      return 0
    fi
  done < <(lsblk -s -n -p -o NAME,TYPE,TRAN,RM,HOTPLUG "$source" 2>/dev/null || true)
  return 1
}

backup_runtime_external_mounts() {
  python3 - <<'PY'
import json
import subprocess
payload = subprocess.check_output([
    'lsblk', '-J', '-p', '-o', 'NAME,TYPE,TRAN,RM,HOTPLUG,MOUNTPOINTS'
], text=True)
data = json.loads(payload)
seen = set()
def walk(node, external=False):
    if node.get('type') == 'disk':
        external = external or node.get('tran') == 'usb' or bool(node.get('rm')) or bool(node.get('hotplug'))
    if external:
        for mountpoint in node.get('mountpoints') or []:
            if mountpoint and mountpoint != '/' and mountpoint not in seen:
                seen.add(mountpoint)
                print(mountpoint)
    for child in node.get('children') or []:
        walk(child, external)
for device in data.get('blockdevices') or []:
    walk(device)
PY
}

backup_runtime_validate_local_target() {
  local path="$1" existing source root_source fstype options required
  existing="$path"
  while [[ ! -e "$existing" && "$existing" != / ]]; do existing="$(dirname "$existing")"; done
  [[ -e "$existing" ]] || return 1
  source="$(findmnt -n -o SOURCE -T "$existing" 2>/dev/null || true)"
  root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  fstype="$(findmnt -n -o FSTYPE -T "$existing" 2>/dev/null || true)"
  options="$(findmnt -n -o OPTIONS -T "$existing" 2>/dev/null || true)"
  [[ -n "$source" && "$source" != "$root_source" ]] || return 1
  backup_runtime_local_source_is_external "$source" || return 1
  required="${BACKUP_PREAPPLY_REQUIRED_FSTYPE:-ext4}"
  [[ -z "$required" || "$fstype" == "$required" ]] || return 1
  [[ ",$options," == *,rw,* ]] || return 1
}

backup_runtime_resolve_repository() {
  local configured="${BACKUP_REPOSITORY:-}" mount subdir
  if [[ -n "$configured" ]]; then
    if backup_runtime_is_remote_repository "$configured"; then
      printf '%s\n' "$configured"
      return 0
    fi
    [[ "$configured" == /* ]] || return 1
    backup_runtime_validate_local_target "$configured" || return 1
    printf '%s\n' "$configured"
    return 0
  fi

  local -a mounts=()
  mapfile -t mounts < <(backup_runtime_external_mounts)
  (( ${#mounts[@]} == 1 )) || return 1
  mount="${mounts[0]}"
  backup_runtime_validate_local_target "$mount" || return 1
  subdir="${BACKUP_PREAPPLY_REPOSITORY_SUBDIR:-Backup-Fedora/restic}"
  [[ -n "$subdir" && "$subdir" != /* && "/$subdir/" != *'/../'* ]] || return 1
  printf '%s/%s\n' "${mount%/}" "$subdir"
}

backup_runtime_password_path() {
  if [[ -n "${BACKUP_PASSWORD_FILE:-}" ]]; then
    printf '%s\n' "$BACKUP_PASSWORD_FILE"
  else
    printf '%s/%s\n' "$HOME" "${BACKUP_PREAPPLY_PASSWORD_FILE_RELATIVE:-.config/fedora-gnome-custom/secrets/restic-password}"
  fi
}

backup_runtime_prepare_password() {
  local file first second mode
  file="$(backup_runtime_password_path)"
  if [[ ! -s "$file" ]]; then
    [[ -t 0 ]] || return 1
    mkdir -p "$(dirname "$file")"
    chmod 0700 "$(dirname "$file")"
    read -r -s -p 'Passphrase Restic (16 caractères minimum): ' first
    printf '\n' >&2
    read -r -s -p 'Confirmer la passphrase Restic: ' second
    printf '\n' >&2
    [[ "$first" == "$second" && ${#first} -ge 16 ]] || return 1
    printf '%s\n' "$first" > "$file"
    chmod 0600 "$file"
    unset first second
  fi
  [[ -r "$file" ]] || return 1
  mode="$(stat -c '%a' "$file")"
  (( (8#$mode & 077) == 0 )) || return 1
  printf '%s\n' "$file"
}

backup_runtime_require_password() {
  local file mode
  file="$(backup_runtime_password_path)"
  [[ -s "$file" && -r "$file" ]] || return 1
  mode="$(stat -c '%a' "$file")"
  (( (8#$mode & 077) == 0 )) || return 1
  printf '%s\n' "$file"
}

backup_runtime_export_env() {
  local repo="$1" password_file="$2"
  export RESTIC_REPOSITORY="$repo"
  export RESTIC_PASSWORD_FILE="$password_file"
}

backup_runtime_capture_inventory() {
  local out="$1"
  mkdir -p "$out"
  {
    printf 'commit=%s\n' "$(repo_commit)"
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'hostname=%s\n' "$(hostname)"
  } > "$out/metadata.txt"
  rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort > "$out/rpm-packages.tsv"
  command -v flatpak >/dev/null 2>&1 && flatpak list --app > "$out/flatpak-apps.txt" || true
  systemctl list-unit-files --state=enabled --no-pager > "$out/systemd-enabled.txt" 2>/dev/null || true
  lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS,TRAN,RM,HOTPLUG,MODEL > "$out/lsblk.txt"
  findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS > "$out/findmnt.txt"
  ip -4 route show > "$out/ip-route.txt" 2>/dev/null || true
  lspci -nnk > "$out/lspci-nnk.txt" 2>/dev/null || true
}

backup_runtime_export_libvirt() {
  local out="$1" uri="${LIBVIRT_URI:-qemu:///system}" name
  mkdir -p "$out/domains" "$out/networks" "$out/pools"
  command -v virsh >/dev/null 2>&1 || return 0
  sudo virsh -c "$uri" list --all --name | sed '/^$/d' > "$out/domains.txt" || true
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    sudo virsh -c "$uri" dumpxml "$name" > "$out/domains/$name.xml"
    sudo virsh -c "$uri" domblklist "$name" --details > "$out/domains/$name-blocks.txt"
  done < "$out/domains.txt"
  sudo virsh -c "$uri" net-list --all --name | sed '/^$/d' > "$out/networks.txt" || true
  while IFS= read -r name; do [[ -n "$name" ]] && sudo virsh -c "$uri" net-dumpxml "$name" > "$out/networks/$name.xml"; done < "$out/networks.txt"
  sudo virsh -c "$uri" pool-list --all --name | sed '/^$/d' > "$out/pools.txt" || true
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    sudo virsh -c "$uri" pool-dumpxml "$name" > "$out/pools/$name.xml"
    sudo virsh -c "$uri" vol-list "$name" --details > "$out/pools/$name-volumes.txt" 2>/dev/null || true
  done < "$out/pools.txt"
}

backup_runtime_require_free_space() {
  local repository="$1" existing available min_bytes min_gib
  backup_runtime_is_remote_repository "$repository" && return 0
  existing="$repository"
  while [[ ! -e "$existing" && "$existing" != / ]]; do existing="$(dirname "$existing")"; done
  min_gib="${BACKUP_PREAPPLY_MIN_FREE_GIB:-20}"
  available="$(df -B1 --output=avail "$existing" | awk 'NR==2 {print $1}')"
  [[ "$available" =~ ^[0-9]+$ && "$min_gib" =~ ^[0-9]+$ ]] || return 1
  min_bytes=$((min_gib * 1024 * 1024 * 1024))
  (( available >= min_bytes ))
}
