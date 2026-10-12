#!/usr/bin/env bash
# Real full archive creation and exact-archive certification in a disposable
# fixture. The platform/inventory commands are simulated, never Gate 3 proof.
# shellcheck disable=SC2016,SC2034,SC1090
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" BORG_BASE_DIR="$tmp/borg-base"
export BACKUP_REPOSITORY="$tmp/borg" STATE_ROOT="$tmp/state"
# Host-independent: the 20 GiB production reserve would make this test depend
# on the free space of whoever runs it. Staging capacity is still exercised.
export BACKUP_PREAPPLY_MIN_FREE_GIB=1
export REPO_ROOT="$tmp/fixture"
mkdir -p "$HOME/.config" "$STATE_ROOT" "$REPO_ROOT/lib" "$REPO_ROOT/scripts/backup" "$tmp/bin"
cp "$ROOT/lib/backup_runtime.sh" "$REPO_ROOT/lib/"
cp "$ROOT/lib/evidence.sh" "$REPO_ROOT/lib/"
cp "$ROOT/scripts/backup/backup-now.sh" "$REPO_ROOT/scripts/backup/"
printf 'settings\n' > "$HOME/.config/settings"
# Ensure a VM metadata file under an otherwise approved directory is excluded.
mkdir -p "$HOME/.config/libvirt"
printf 'private owner-managed VM XML\n' > "$HOME/.config/libvirt/manual-domain.xml"
cat > "$REPO_ROOT/lib/install_lock.sh" <<'MOCK'
install_lock_acquire() { return 0; }
MOCK
cat > "$REPO_ROOT/lib/persistent_data.sh" <<'MOCK'
# No real persistent-data mount in this fixture.
MOCK
cat > "$REPO_ROOT/lib/bootstrap.sh" <<'MOCK'
engine_bootstrap() {
  source "$REPO_ROOT/lib/evidence.sh"
  effective_config_sha256() { printf '%064d\n' "${TEST_CONFIG:-1}"; }
  module_plan_sha256() { printf '%064d\n' 2; }
  evidence_hardware_fingerprint() { echo deferred:container; }
}
repo_commit() { printf '%040d\n' 1; }
effective_config_sha256() { printf '%064d\n' "${TEST_CONFIG:-1}"; }
module_plan_sha256() { printf '%064d\n' 2; }
evidence_hardware_fingerprint() { echo deferred:container; }
runtime_is_baremetal() { return 1; }
is_true() { [[ "$1" == true ]]; }
MOCK
cat >> "$REPO_ROOT/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$BACKUP_REPOSITORY" ]]; }
backup_runtime_capture_inventory() { mkdir -p "$1"; printf 'inventory\n' > "$1/metadata.txt"; }
backup_runtime_export_libvirt() { echo 'Unexpected automatic libvirt export' >&2; exit 99; }
MOCK
cat > "$tmp/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" != -n ]] || shift
if [[ "$1" == du && "$*" == *'/etc /boot'* ]]; then echo '4096 total'; exit; fi
if [[ "$1" == tar ]]; then
  while (($#)); do
    if [[ "$1" == -czf ]]; then printf 'fixture system configuration\n' > "$2"; exit; fi
    shift
  done
fi
exec "$@"
MOCK
cat > "$tmp/bin/xdg-user-dir" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$HOME/.config"
MOCK
cat > "$tmp/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
git -C "$REPO_ROOT" init -q
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/backup_runtime.sh"
backup_engine_env "$BACKUP_REPOSITORY"
backup_engine_init >/dev/null
bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/staging"
marker="$STATE_ROOT/last-full-backup.ok"
backup_runtime_validate_full_marker "$marker"
archive="$(evidence_marker_value "$marker" archive)"
snapshot="$(evidence_marker_value "$marker" snapshot)"
manifest="$(backup_runtime_recovery_manifest "$archive")"
[[ "$(jq -r '.include_vms' <<<"$manifest")" == false ]]
[[ "$(jq -r '.vm_count' <<<"$manifest")" == 0 ]]
[[ "$(jq -c '.vm_names' <<<"$manifest")" == '[]' ]]
[[ "$(jq -r '.include_vms' <<<"$manifest")" == false ]]
if borg list "::$archive" | grep -Fq 'manual-domain.xml'; then
  echo 'Manual libvirt domain XML was archived by Borg' >&2
  exit 1
fi
backup_runtime_full_vm_coverage_valid "$marker"
# The VM-export policy cannot be enabled, even if a local override is set.
for flag in BACKUP_VM_DISKS BACKUP_LIBVIRT_METADATA BACKUP_VM_CLOUD_INIT_METADATA; do
  if env "$flag=true" bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/rejected-$flag" > "$tmp/rejected-$flag.log" 2>&1; then
    echo "Owner-managed VM policy bypassed: $flag" >&2; exit 1
  fi
  grep -Fq 'VM backup/export is manual-only' "$tmp/rejected-$flag.log"
done
# Invalid/legacy manifests must not earn a current host-only certificate.
coverage="$tmp/vm-coverage.ok"
printf 'include_vms=true\nvm_count=1\nvm_names_sha256=%s\n' "$(printf '[\"demo\"]' | sha256sum | awk '{print $1}')" > "$coverage"
if backup_runtime_full_vm_coverage_valid "$coverage"; then
  echo 'Legacy VM-inclusive backup incorrectly certified' >&2; exit 1
fi
# A newer daily archive never becomes an OS recovery base.
read -r daily _ < <(backup_engine_create daily -- "$HOME/.config")
read -r selected selected_id < <(backup_engine_latest full)
[[ "$selected" == "$archive" && "$selected_id" == "$snapshot" && "$daily" != "$selected" ]]
# A real archive written by a warning must stay outside the recovery namespace.
real_borg="$(command -v borg)"
borg() {
  if [[ "$1" == create ]]; then
    "$real_borg" "$@" || return $?
    return 1
  fi
  "$real_borg" "$@"
}
rc=0
out="$(backup_engine_create full --comment "$manifest" -- "$HOME/.config")" || rc=$?
[[ "$rc" == 1 && -z "$out" ]]
read -r selected selected_id < <(backup_engine_latest full)
[[ "$selected" == "$archive" && "$selected_id" == "$snapshot" ]]
[[ -n "$("$real_borg" list --glob-archives 'fgc-pending-full-*' --short)" ]]
unset -f borg
read -r selected _ < <(backup_engine_latest '')
[[ "$selected" != fgc-pending-* ]]
cp "$marker" "$tmp/good-marker"
sed -i 's/^integrity_check=PASS/integrity_check=FAIL/' "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Failed integrity accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
if TEST_CONFIG=3 backup_runtime_validate_full_marker "$marker"; then echo 'Stale config accepted' >&2; exit 1; fi
sed -i "s|^repository=.*|repository=$tmp/wrong-repository|" "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Different repository accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
"$real_borg" delete "::$archive"
if backup_runtime_validate_full_marker "$marker"; then echo 'Deleted exact archive accepted' >&2; exit 1; fi
if backup_runtime_recovery_manifest "$daily"; then echo 'Daily recovery manifest accepted' >&2; exit 1; fi
read -r legacy _ < <(backup_engine_create full -- "$HOME/.config")
if backup_runtime_recovery_manifest "$legacy"; then echo 'Legacy archive certified without manifest' >&2; exit 1; fi

# Warnings/errors must return no archive identity to any success-marker caller.
borg() { printf '{"archive":{"name":"ignored","id":"%064d"}}\n' 1; return "$TEST_BORG_RC"; }
for TEST_BORG_RC in 1 2; do
  rc=0
  output="$(backup_engine_create full -- "$HOME/.config")" || rc=$?
  [[ "$rc" == "$TEST_BORG_RC" && -z "$output" ]]
done
unset -f borg
# Manual-only means the old flag must be rejected before any Borg or VM work.
if bash "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms > "$tmp/unsupported-flag.log" 2>&1; then
  echo 'Deprecated VM automatic backup flag unexpectedly succeeded' >&2; exit 1
fi
grep -Fq 'owner-managed' "$tmp/unsupported-flag.log"
echo 'Backup certification behavior: PASS'
