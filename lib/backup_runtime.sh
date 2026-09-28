#!/usr/bin/env bash

# Borg 1.x remote repositories: ssh://user@host[:port]/path or user@host:path.
backup_runtime_is_remote_repository() {
  local repo="$1"
  [[ "$repo" =~ ^ssh:// || "$repo" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+: ]]
}

backup_runtime_local_source_is_external() {
  local source="$1" name type tran rm hotplug
  source="$(readlink -f -- "$source" 2>/dev/null || true)"
  [[ -n "$source" && -b "$source" ]] || return 1
  while read -r name type tran rm hotplug; do
    [[ "$type" == disk ]] || continue
    if [[ "$tran" == usb || "$rm" == 1 || "$hotplug" == 1 ]]; then return 0; fi
  done < <(lsblk -s -n -p -o NAME,TYPE,TRAN,RM,HOTPLUG "$source" 2>/dev/null || true)
  return 1
}

backup_runtime_external_mounts() {
  python3 - <<'PY'
import json, subprocess
payload = subprocess.check_output(['lsblk','-J','-p','-o','NAME,TYPE,TRAN,RM,HOTPLUG,MOUNTPOINTS'], text=True)
data = json.loads(payload)
seen=set()
def walk(node, external=False):
    if node.get('type') == 'disk':
        external = external or node.get('tran') == 'usb' or bool(node.get('rm')) or bool(node.get('hotplug'))
    if external:
        for mountpoint in node.get('mountpoints') or []:
            if mountpoint and mountpoint != '/' and mountpoint not in seen:
                seen.add(mountpoint); print(mountpoint)
    for child in node.get('children') or []: walk(child, external)
for device in data.get('blockdevices') or []: walk(device)
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
  [[ ",$options," == *,rw,* ]]
}

backup_runtime_resolve_repository() {
  local configured="${BACKUP_REPOSITORY:-}" mount subdir
  if [[ -n "$configured" ]]; then
    if backup_runtime_is_remote_repository "$configured"; then printf '%s\n' "$configured"; return 0; fi
    [[ "$configured" == /* ]] || return 1
    backup_runtime_validate_local_target "$configured" || return 1
    printf '%s\n' "$configured"; return 0
  fi
  local -a mounts=()
  mapfile -t mounts < <(backup_runtime_external_mounts)
  (( ${#mounts[@]} == 1 )) || return 1
  mount="${mounts[0]}"
  backup_runtime_validate_local_target "$mount" || return 1
  subdir="${BACKUP_PREAPPLY_REPOSITORY_SUBDIR:-Backup-Fedora/borg}"
  [[ -n "$subdir" && "$subdir" != /* && "/$subdir/" != *'/../'* ]] || return 1
  printf '%s/%s\n' "${mount%/}" "$subdir"
}

# --- Borg engine (ADR 0014: unencrypted Borg 1.x repository) -----------------
# Every Borg call goes through these helpers, so the engine, the archive naming
# and the "no encryption" policy live in exactly one place.
# Archives are named fgc-<kind>-<UTC stamp>; kinds: preapply, full, daily.

BACKUP_ARCHIVE_PREFIX='fgc'

backup_engine_env() {
  export BORG_REPO="$1"
  # Unencrypted by explicit owner decision: there is no passphrase at all.
  # An explicitly empty passphrase also guarantees that an *encrypted*
  # repository fails immediately instead of waiting for a password prompt.
  unset BORG_PASSCOMMAND BORG_PASSPHRASE_FD BORG_NEW_PASSPHRASE
  export BORG_PASSPHRASE=
  # Non-interactive runs (timers, pre-APPLY) must not stop on Borg prompts:
  # an unencrypted repository, or the external disk mounted at a new path.
  export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
  export BORG_EXIT_CODES="${BORG_EXIT_CODES:-legacy}"
}

backup_engine_require() {
  local version
  command -v borg >/dev/null 2>&1 || { echo 'borg (borgbackup) is required.' >&2; return 1; }
  version="$(BORG_PASSPHRASE='' borg --version 2>/dev/null)" || return 1
  [[ "$version" =~ ^borg[[:space:]]+1\.(2|3|4)\. ]] || { echo "Unsupported Borg version: $version (Borg 1.2-1.4 required)." >&2; return 1; }
}

backup_engine_kind_valid() { [[ "$1" =~ ^(preapply|full|daily)$ ]]; }

# Reachable repository whose encryption mode is exactly "none".
backup_engine_repo_ready() {
  local json
  json="$(borg info --json 2>/dev/null)" || return 1
  python3 -c 'import json,sys
d=json.load(sys.stdin)
raise SystemExit(0 if (d.get("encryption") or {}).get("mode") == "none" else 3)' <<<"$json"
}

backup_engine_init() {
  borg init --encryption=none --make-parent-dirs
}

# backup_engine_create KIND [--exclude PATTERN]... -- SOURCE...
# Prints "<archive name> <archive id>" of the archive that was just written.
backup_engine_create() {
  local kind="$1" name json
  shift
  backup_engine_kind_valid "$kind" || return 2
  local -a opts=()
  while (($#)) && [[ "$1" != -- ]]; do
    [[ "$1" == --exclude && -n "${2:-}" ]] || return 2
    opts+=(--exclude "$2"); shift 2
  done
  [[ "${1:-}" == -- ]] || return 2
  shift
  (($# > 0)) || return 2
  name="${BACKUP_ARCHIVE_PREFIX}-${kind}-$(date -u +%Y%m%dT%H%M%S.%NZ)"
  # Legacy exit codes: 0 = OK, 1 = warning (e.g. a file changed while being
  # read; the archive IS written), 2+ = error. Warnings are reported, not fatal.
  local rc=0
  json="$(borg create --json --compression zstd,3 --exclude-caches "${opts[@]}" "::$name" "$@")" || rc=$?
  (( rc <= 1 )) || return "$rc"
  (( rc == 0 )) || echo "Borg reported warnings while creating $name (archive written)." >&2
  python3 -c 'import json,sys
a=json.load(sys.stdin)["archive"]
name, aid = a.get("name",""), a.get("id","")
assert name == sys.argv[1] and len(aid) == 64 and all(c in "0123456789abcdef" for c in aid.lower())
print(name, aid)' "$name" <<<"$json"
}

# Prints "<archive name> <archive id>" of the newest archive of KIND (or of any kind).
backup_engine_latest() {
  local kind="${1:-}" pattern json
  if [[ -n "$kind" ]]; then backup_engine_kind_valid "$kind" || return 2; pattern="${BACKUP_ARCHIVE_PREFIX}-${kind}-*"; else pattern="${BACKUP_ARCHIVE_PREFIX}-*"; fi
  json="$(borg list --json --glob-archives "$pattern" --last 1)" || return $?
  python3 -c 'import json,sys
arch=json.load(sys.stdin).get("archives") or []
if not arch: raise SystemExit(1)
print(arch[-1]["name"], arch[-1]["id"])' <<<"$json"
}

# True when archive NAME exists with exactly id ID and belongs to KIND.
backup_engine_archive_matches() {
  local name="$1" id="$2" kind="$3" json
  backup_engine_kind_valid "$kind" || return 1
  [[ "$name" == "${BACKUP_ARCHIVE_PREFIX}-${kind}-"* && "$id" =~ ^[0-9a-f]{64}$ ]] || return 1
  json="$(borg info --json "::$name" 2>/dev/null)" || return 1
  python3 -c 'import json,sys
arch=json.load(sys.stdin).get("archives") or [{}]
raise SystemExit(0 if arch[0].get("id") == sys.argv[1] else 1)' "$id" <<<"$json"
}

# Full repository + archive metadata check; with KIND, also re-reads and
# verifies the data of the newest archive of that kind (--verify-data).
backup_engine_check() {
  local kind="${1:-}"
  if [[ -z "$kind" ]]; then borg check; return $?; fi
  backup_engine_kind_valid "$kind" || return 2
  borg check --verify-data --glob-archives "${BACKUP_ARCHIVE_PREFIX}-${kind}-*" --last 1
}

# backup_engine_extract ARCHIVE TARGET_DIR [ABSOLUTE_PATH...]
# Borg stores /a/b as a/b: extraction recreates TARGET_DIR/a/b.
backup_engine_extract() {
  local archive="$1" target="$2" path
  shift 2
  local -a paths=()
  for path in "$@"; do paths+=("${path#/}"); done
  ( cd "$target" && borg extract "::$archive" "${paths[@]}" )
}

backup_engine_prune() {
  local kind="$1"
  backup_engine_kind_valid "$kind" || return 2
  borg prune --glob-archives "${BACKUP_ARCHIVE_PREFIX}-${kind}-*" \
    --keep-daily "${BACKUP_KEEP_DAILY:-7}" \
    --keep-weekly "${BACKUP_KEEP_WEEKLY:-4}" \
    --keep-monthly "${BACKUP_KEEP_MONTHLY:-6}"
}

backup_engine_compact() { borg compact; }

backup_runtime_capture_inventory() {
  local out="$1"; mkdir -p "$out"
  {
    printf 'commit=%s\n' "$(repo_commit)"; printf 'run_id=%s\n' "$RUN_ID"; printf 'utc=%s\n' "$(date -u +%FT%TZ)"; printf 'hostname=%s\n' "$(hostname)"
    printf 'effective_config_sha256=%s\n' "$(effective_config_sha256)"; printf 'module_plan_sha256=%s\n' "$(module_plan_sha256)"
  } > "$out/metadata.txt"
  rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort > "$out/rpm-packages.tsv"
  if command -v flatpak >/dev/null 2>&1; then flatpak list --app > "$out/flatpak-apps.txt"; fi
  systemctl list-unit-files --state=enabled --no-pager > "$out/systemd-enabled.txt" 2>/dev/null || true
  lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS,TRAN,RM,HOTPLUG,MODEL > "$out/lsblk.txt"
  findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS > "$out/findmnt.txt"
  ip -4 route show > "$out/ip-route.txt" 2>/dev/null || true
  ip -4 rule show > "$out/ip-rule.txt" 2>/dev/null || true
  lspci -nnk > "$out/lspci-nnk.txt" 2>/dev/null || true
}

backup_runtime_virsh_capture() { local uri="$1" output="$2"; shift 2; sudo virsh -c "$uri" "$@" | cat > "$output"; }

backup_runtime_export_libvirt() {
  local out="$1" uri="${LIBVIRT_URI:-qemu:///system}" name
  mkdir -p "$out/domains" "$out/networks" "$out/pools"
  command -v virsh >/dev/null 2>&1 || {
    printf 'libvirt_metadata=unavailable\n' > "$out/metadata-status.env"
    return 0
  }
  sudo virsh -c "$uri" list --all --name | sed '/^$/d' > "$out/domains.txt" || return $?
  while IFS= read -r name; do [[ -n "$name" ]] || continue; backup_runtime_virsh_capture "$uri" "$out/domains/$name.xml" dumpxml "$name"; backup_runtime_virsh_capture "$uri" "$out/domains/$name-blocks.txt" domblklist "$name" --details; done < "$out/domains.txt"
  sudo virsh -c "$uri" net-list --all --name | sed '/^$/d' > "$out/networks.txt" || return $?
  while IFS= read -r name; do [[ -n "$name" ]] || continue; backup_runtime_virsh_capture "$uri" "$out/networks/$name.xml" net-dumpxml "$name"; done < "$out/networks.txt"
  sudo virsh -c "$uri" pool-list --all --name | sed '/^$/d' > "$out/pools.txt" || return $?
  while IFS= read -r name; do [[ -n "$name" ]] || continue; backup_runtime_virsh_capture "$uri" "$out/pools/$name.xml" pool-dumpxml "$name"; backup_runtime_virsh_capture "$uri" "$out/pools/$name-volumes.txt" vol-list "$name" --details 2>/dev/null || : > "$out/pools/$name-volumes.txt"; done < "$out/pools.txt"
}

backup_runtime_require_free_space() {
  local repository="$1" existing available min_bytes min_gib
  backup_runtime_is_remote_repository "$repository" && return 0
  existing="$repository"; while [[ ! -e "$existing" && "$existing" != / ]]; do existing="$(dirname "$existing")"; done
  min_gib="${BACKUP_PREAPPLY_MIN_FREE_GIB:-20}"; available="$(df -B1 --output=avail "$existing" | awk 'NR==2 {print $1}')"
  [[ "$available" =~ ^[0-9]+$ && "$min_gib" =~ ^[0-9]+$ ]] || return 1
  min_bytes=$((min_gib * 1024 * 1024 * 1024)); (( available >= min_bytes ))
}

backup_runtime_validate_preapply_marker() {
  local marker="$1" snapshot archive repo
  backup_engine_require >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  snapshot="$(evidence_marker_value "$marker" snapshot 2>/dev/null || true)"
  archive="$(evidence_marker_value "$marker" archive 2>/dev/null || true)"
  repo="$(evidence_marker_value "$marker" repository 2>/dev/null || true)"
  [[ "$snapshot" =~ ^[0-9a-f]{64}$ && -n "$archive" && -n "$repo" ]] || return 1
  if ! backup_runtime_is_remote_repository "$repo"; then backup_runtime_validate_local_target "$repo" || return 1; fi
  backup_engine_env "$repo"
  backup_engine_repo_ready || return 1
  backup_engine_archive_matches "$archive" "$snapshot" preapply
}

# A restore is restricted to the configured staging tree, including when the
# caller supplies an explicit target. Canonicalization also rejects symlink
# escapes and ../ paths before any files are created.
backup_runtime_restore_target_valid() {
  local target root
  root="$(readlink -m -- "${BACKUP_RESTORE_STAGING_ROOT:-$HOME/Restores/fedora-gnome-custom}")" || return 1
  target="$(readlink -m -- "$1")" || return 1
  case "$root" in
    /|/etc|/etc/*|/boot|/boot/*|/usr|/usr/*|/var|/var/*|/home|"$HOME"|/data|"${KVM_POOL_PATH:-/data/libvirt/images}"|"${KVM_POOL_PATH:-/data/libvirt/images}"/*) return 1 ;;
  esac
  [[ "$target" == "$root" || "$target" == "$root/"* ]]
}
