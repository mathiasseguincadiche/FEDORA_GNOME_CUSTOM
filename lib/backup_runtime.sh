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
  export BORG_EXIT_CODES=legacy
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
# Prints the number of tolerated "file changed while we backed it up" warnings
# (0 when rc=0). Fails when anything else was logged at WARNING/ERROR level,
# for any non-daily archive with warnings, or for any rc other than 0/1.
backup_engine_tolerated_changes() {
  local kind="$1" rc="$2" log="$3"
  (( rc == 0 || rc == 1 )) || return 1
  python3 - "$kind" "$rc" "$log" <<'PY'
import json, sys
kind, rc, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
changed, other = 0, 0
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
    except ValueError:
        other += 1          # anything that is not Borg's own JSON log is suspect
        continue
    if entry.get("type") != "log_message" or entry.get("levelname") not in ("WARNING", "ERROR", "CRITICAL"):
        continue
    message = str(entry.get("message", ""))
    if entry.get("levelname") == "WARNING" and message.endswith(": file changed while we backed it up"):
        changed += 1
    else:
        other += 1
if other or (rc == 1 and (kind != "daily" or changed == 0)) or (rc == 0 and changed):
    sys.exit(1)
print(changed)
PY
}

# Human-readable view of Borg's JSON log (stderr is otherwise machine-only).
backup_engine_print_log() {
  python3 - "$1" <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    try:
        entry = json.loads(line)
        if entry.get("type") == "log_message":
            print(f"borg {entry.get('levelname', '?')}: {entry.get('message', '')}")
    except ValueError:
        if line:
            print(line)
PY
}

backup_engine_create() {
  local kind="$1" name pending json comment identity
  shift
  backup_engine_kind_valid "$kind" || return 2
  local -a opts=()
  while (($#)) && [[ "$1" != -- ]]; do
    [[ ( "$1" == --exclude || "$1" == --comment ) && -n "${2:-}" ]] || return 2
    if [[ "$1" == --comment ]]; then
      # Borg formats placeholders in --comment; escape JSON braces so the
      # stored recovery manifest is literal JSON.
      comment="$(python3 -c 'import sys; print(sys.argv[1].replace("{","{{").replace("}","}}"))' "$2")" || return 2
      opts+=(--comment "$comment")
    else
      opts+=(--exclude "$2")
    fi
    shift 2
  done
  [[ "${1:-}" == -- ]] || return 2
  shift
  (($# > 0)) || return 2
  name="${BACKUP_ARCHIVE_PREFIX}-${kind}-$(date -u +%Y%m%dT%H%M%S.%NZ)"
  pending="${BACKUP_ARCHIVE_PREFIX}-pending-${kind}-${name#"${BACKUP_ARCHIVE_PREFIX}-${kind}-"}"
  # A warning can mean unreadable/omitted files. Only rc=0 proves creation
  # succeeded; an archive written with warnings never produces a success marker.
  local rc=0 log changed
  log="$(mktemp)"
  json="$(borg create --json --log-json --compression zstd,3 --exclude-caches "${opts[@]}" "::$pending" "$@" 2>"$log")" || rc=$?
  # Daily archives of a live session may legitimately see a file change while it
  # is read (browser profile, Flatpak data): the archive is complete and keeps
  # the version read. Only that exact warning is tolerated, only for `daily`;
  # pre-APPLY and full archives stay strict (any warning = failure).
  changed="$(backup_engine_tolerated_changes "$kind" "$rc" "$log")" || {
    backup_engine_print_log "$log" >&2
    rm -f "$log"
    echo "Borg creation refused certification for $name (rc=$rc; warnings may omit files)." >&2
    return "$(( rc == 0 ? 2 : rc ))"
  }
  backup_engine_print_log "$log" >&2
  rm -f "$log"
  [[ -z "${BACKUP_ENGINE_WARNINGS_REPORT:-}" ]] || printf 'files_changed_during_backup=%s\n' "$changed" > "$BACKUP_ENGINE_WARNINGS_REPORT"
  identity="$(python3 -c 'import json,sys
a=json.load(sys.stdin)["archive"]
name, aid = a.get("name",""), a.get("id","")
assert name == sys.argv[1] and len(aid) == 64 and all(c in "0123456789abcdef" for c in aid.lower())
print(name, aid)' "$pending" <<<"$json")" || return 2
  [[ -n "$identity" ]] || return 2
  # Warning archives remain inspectable under fgc-pending-* and are excluded
  # from every daily/full/preapply selector and automatic retention policy.
  borg rename "::$pending" "$name" || return $?
  # Rename changes archive metadata and its id: re-read the promoted identity.
  json="$(borg info --json "::$name")" || return $?
  python3 -c 'import json,sys
a=json.load(sys.stdin)["archives"]
assert len(a)==1 and a[0]["name"]==sys.argv[1]
aid=a[0]["id"]
assert len(aid)==64 and all(c in "0123456789abcdef" for c in aid)
print(a[0]["name"],aid)' "$name" <<<"$json"
}

# Prints "<archive name> <archive id>" of the newest archive of KIND (or of any kind).
backup_engine_latest() {
  local kind="${1:-}" pattern json
  local -a limit=()
  if [[ -n "$kind" ]]; then
    backup_engine_kind_valid "$kind" || return 2
    pattern="${BACKUP_ARCHIVE_PREFIX}-${kind}-*"; limit=(--last 1)
  else
    pattern="${BACKUP_ARCHIVE_PREFIX}-*"
  fi
  json="$(borg list --json --glob-archives "$pattern" --sort-by timestamp "${limit[@]}")" || return $?
  python3 -c 'import json,re,sys
arch=[a for a in (json.load(sys.stdin).get("archives") or [])
      if re.match(r"^fgc-(preapply|full|daily)-",a.get("name",""))]
if not arch: raise SystemExit(1)
print(arch[-1]["name"], arch[-1]["id"])' <<<"$json"
}

# True when archive NAME exists with exactly id ID and belongs to KIND.
backup_engine_archive_matches() {
  local name="$1" id="$2" kind="$3" json
  backup_engine_kind_valid "$kind" || return 1
  [[ "$name" == "${BACKUP_ARCHIVE_PREFIX}-${kind}-"* && "$name" =~ ^[A-Za-z0-9_.-]+$ && "$id" =~ ^[0-9a-f]{64}$ ]] || return 1
  json="$(borg info --json "::$name" 2>/dev/null)" || return 1
  python3 -c 'import json,sys
arch=json.load(sys.stdin).get("archives") or [{}]
raise SystemExit(0 if arch[0].get("id") == sys.argv[1] else 1)' "$id" <<<"$json"
}

# Full repository + archive metadata check; with KIND, also re-reads and
# verifies the data of the explicitly selected archive (--verify-data).
backup_engine_check() {
  local kind="${1:-}" archive="${2:-}"
  if [[ -z "$kind" ]]; then borg check; return $?; fi
  backup_engine_kind_valid "$kind" || return 2
  [[ "$archive" == "${BACKUP_ARCHIVE_PREFIX}-${kind}-"* && "$archive" =~ ^[A-Za-z0-9_.-]+$ ]] || return 2
  borg check --verify-data --glob-archives "$archive"
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

# Archives that failed certification stay inspectable as fgc-pending-*, but
# must not accumulate forever: keep only the newest BACKUP_KEEP_PENDING.
backup_engine_prune_pending() {
  local keep="${BACKUP_KEEP_PENDING:-3}"
  [[ "$keep" =~ ^[1-9][0-9]*$ ]] || return 2
  borg prune --glob-archives "${BACKUP_ARCHIVE_PREFIX}-pending-*" --keep-last "$keep"
}

backup_engine_pending_count() {
  local listing
  listing="$(borg list --short --glob-archives "${BACKUP_ARCHIVE_PREFIX}-pending-*")" || return 1
  grep -c . <<<"$listing" || true
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
  [[ "$(evidence_marker_value "$marker" verdict)" == PASS &&
     "$(evidence_marker_value "$marker" integrity_check)" == PASS &&
     "$(evidence_marker_value "$marker" restore_test)" == PASS ]] || return 1
  [[ "$repo" == "$(backup_runtime_resolve_repository)" ]] || return 1
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

# Local capacity is checked before writing. Preserve 1 GiB on the staging
# filesystem; repository checks preserve the configured minimum reserve.
backup_runtime_require_staging_space() {
  local path="$1" required="$2" reserve="${3:-1073741824}" available
  [[ "$required" =~ ^[0-9]+$ && "$reserve" =~ ^[0-9]+$ ]] || return 1
  available="$(df -B1 --output=avail "$path" | awk 'NR==2 {print $1}')" || return 1
  [[ "$available" =~ ^[0-9]+$ ]] || return 1
  (( required <= available && reserve <= available - required ))
}

backup_runtime_require_source_capacity() {
  local repository="$1" bytes reserve
  if backup_runtime_is_remote_repository "$repository"; then
    echo 'Remote repository capacity cannot be measured locally; Borg errors remain fatal.' >&2
    return 0
  fi
  shift
  bytes="$(du -scB1 -- "$@" | awk 'END {print $1}')" || return 1
  [[ "${BACKUP_PREAPPLY_MIN_FREE_GIB:-20}" =~ ^[0-9]+$ ]] || return 1
  reserve=$(( ${BACKUP_PREAPPLY_MIN_FREE_GIB:-20} * 1024 * 1024 * 1024 ))
  backup_runtime_require_staging_space "$repository" "$bytes" "$reserve"
}

# A recovery manifest lives in the exact full archive's Borg comment.
# Older full archives without this manifest are deliberately not certified.
backup_runtime_recovery_manifest() {
  local archive="$1" json
  [[ "$archive" == fgc-full-* && "$archive" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
  json="$(borg info --json "::$archive")" || return 1
  python3 -c 'import hashlib,json,re,sys
a=json.load(sys.stdin)["archives"]
assert len(a)==1 and a[0]["name"]==sys.argv[1]
m=json.loads(a[0]["comment"])
assert m["schema"]==1 and m["kind"]=="full" and m["engine"]=="borg" and m["encryption"]=="none"
assert re.fullmatch(r"[0-9a-f]{40}",m["commit"])
for k in ("effective_config_sha256","module_plan_sha256","canary_sha256"):
    assert re.fullmatch(r"[0-9a-f]{64}",m[k])
assert type(m["include_vms"]) is bool and type(m["vm_count"]) is int and m["vm_count"]>=0
assert m["include_vms"] or m["vm_count"]==0
assert isinstance(m["vm_names"],list) and len(m["vm_names"])==m["vm_count"]
assert all(isinstance(n,str) and re.fullmatch(r"[A-Za-z0-9_.-]+",n) for n in m["vm_names"])
assert len(set(m["vm_names"]))==len(m["vm_names"])
assert re.fullmatch(r"[0-9a-f]{64}",m["vm_names_sha256"])
assert m["vm_names"]==sorted(m["vm_names"])
assert hashlib.sha256(json.dumps(m["vm_names"],separators=(",",":")).encode()).hexdigest()==m["vm_names_sha256"]
assert m["canary_path"].endswith("/restore-canary.txt") and not m["canary_path"].startswith("/")
assert ".." not in m["canary_path"].split("/")
print(json.dumps(m,sort_keys=True))' "$archive" <<<"$json"
}

backup_runtime_validate_full_marker() {
  local marker="$1" repo archive snapshot manifest expected actual key
  evidence_require_current_identity "$marker" || return 1
  for key in verdict integrity_check restore_test; do
    [[ "$(evidence_marker_value "$marker" "$key")" == PASS ]] || return 1
  done
  repo="$(backup_runtime_resolve_repository)" || return 1
  [[ "$repo" == "$(evidence_marker_value "$marker" repository)" ]] || return 1
  archive="$(evidence_marker_value "$marker" archive)" || return 1
  snapshot="$(evidence_marker_value "$marker" snapshot)" || return 1
  backup_engine_require && backup_engine_env "$repo" && backup_engine_repo_ready || return 1
  backup_engine_archive_matches "$archive" "$snapshot" full || return 1
  manifest="$(backup_runtime_recovery_manifest "$archive")" || return 1
  for key in commit effective_config_sha256 module_plan_sha256 hardware_fingerprint include_vms vm_count vm_names_sha256; do
    actual="$(jq -r --arg k "$key" '.[$k] | tostring' <<<"$manifest")" || return 1
    [[ "$actual" == "$(evidence_marker_value "$marker" "$key")" ]] || return 1
  done
  expected="$(jq -r '.canary_sha256' <<<"$manifest")" || return 1
  actual="$(borg extract --stdout "::$archive" "$(jq -r '.canary_path' <<<"$manifest")" | sha256sum | awk '{print $1}')" || return 1
  [[ "$actual" == "$expected" ]]
}

backup_runtime_recovery_canary_valid() {
  local archive="$1" manifest="$2" expected actual path
  expected="$(jq -r '.canary_sha256' <<<"$manifest")" || return 1
  path="$(jq -r '.canary_path' <<<"$manifest")" || return 1
  actual="$(borg extract --stdout "::$archive" "$path" | sha256sum | awk '{print $1}')" || return 1
  [[ "$actual" == "$expected" ]]
}

backup_runtime_atomic_write() {
  local path="$1" temporary
  temporary="$(mktemp "$(dirname "$path")/.backup-evidence.XXXXXX")" || return 1
  if ! cat > "$temporary" || ! chmod 0600 "$temporary" || ! mv -f "$temporary" "$path"; then
    rm -f "$temporary"
    return 1
  fi
}

# Gate 3 must honor the configured VM-disk policy, not merely an optional
# command-line flag. Compare the current domain set with the archived set.
backup_runtime_full_vm_coverage_valid() {
  local marker="$1" count names canonical digest
  if ! is_true "${ENABLE_KVM:-true}" || ! is_true "${BACKUP_VM_DISKS:-true}"; then return 0; fi
  [[ "$(evidence_marker_value "$marker" include_vms)" == true ]] || return 1
  count="$(evidence_marker_value "$marker" vm_count)" || return 1
  [[ "$count" =~ ^[0-9]+$ ]] || return 1
  command -v virsh >/dev/null 2>&1 || return 1
  names="$(sudo -n virsh -c "${LIBVIRT_URI:-qemu:///system}" list --all --name)" || return 1
  canonical="$(printf '%s\n' "$names" | jq -Rsc 'split("\n") | map(select(length > 0)) | sort')" || return 1
  [[ "$(jq 'length' <<<"$canonical")" == "$count" ]] || return 1
  digest="$(printf '%s' "$canonical" | sha256sum | awk '{print $1}')" || return 1
  [[ "$digest" == "$(evidence_marker_value "$marker" vm_names_sha256)" ]]
}
