#!/usr/bin/env bash
# Run the real upgrade entrypoint in a disposable fixture. No live OS mutation.
# Refusals must happen before backup/download, and failed downloads create no state.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts/maintenance" "$tmp/scripts/backup" "$tmp/lib" "$tmp/bin" "$tmp/state" "$tmp/diagnostics"
cp "$ROOT/scripts/maintenance/upgrade-fedora.sh" "$tmp/scripts/maintenance/"
cp "$ROOT/lib/evidence.sh" "$tmp/lib/"
printf 'install_lock_acquire() { return 0; }\n' > "$tmp/lib/install_lock.sh"
cat > "$tmp/lib/bootstrap.sh" <<'SH'
EXIT_SECURITY_BLOCK=50
EXIT_CONFIG_FAILED=60
EXIT_PRECHECK_FAILED=20
EXIT_POSTCHECK_FAILED=40
engine_bootstrap() { STATE_ROOT="$REPO_ROOT/state"; HOST_RELEASE=44; }
runtime_is_baremetal() { [[ "${FAKE_VM:-false}" == false ]]; }
fedora_require_profile() { [[ "${FAKE_PROFILE:-pending}" == ready ]]; }
fedora_require_selected() { return 0; }
fedora_actual_release() { echo "${FAKE_OS:-44}"; }
apply_gate_require_clean_git() { [[ "${FAKE_DIRTY:-false}" == false ]]; }
ui_error() { echo "$*" >&2; }
repo_commit() { printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'; }
effective_config_sha256() { printf '%064d\n' 0; }
source "$REPO_ROOT/lib/evidence.sh"
SH
cat > "$tmp/lib/kernel_lifecycle.sh" <<'SH'
kernel_lifecycle_require_host_gate() { return 0; }
kernel_lifecycle_ensure_tooling_and_repo() { return 0; }
kernel_lifecycle_ensure_dnf_retention() { return 0; }
kernel_lifecycle_resolve_latest_stable() { echo '7.2.9-200.vanilla.fc45.x86_64'; }
kernel_lifecycle_pin_target() { echo pin >> "$FGC_TRACE"; }
kernel_lifecycle_lock_hash() { printf '%064d\n' 1; }
SH
cat > "$tmp/scripts/backup/backup-now.sh" <<'SH'
#!/usr/bin/env bash
echo backup >> "$FGC_TRACE"
(( ${FAKE_BACKUP_RC:-0} == 0 )) || exit "$FAKE_BACKUP_RC"
printf 'snapshot=%064d\n' 2 > "$(dirname "$0")/../../state/last-full-backup.ok"
SH
cat > "$tmp/diagnostics/backup-doctor" <<'SH'
#!/usr/bin/env bash
echo certify >> "$FGC_TRACE"
SH
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$FGC_TRACE"
case "$*" in *check-upgrade*) exit "${FAKE_UPDATES_RC:-0}" ;; *system-upgrade*download*) exit "${FAKE_DOWNLOAD_RC:-0}" ;; esac
SH
chmod +x "$tmp/bin/"* "$tmp/scripts/backup/backup-now.sh" "$tmp/diagnostics/backup-doctor"
export FGC_TRACE="$tmp/trace" PATH="$tmp/bin:$PATH"
run_expect() {
  local expected="$1" action="$2" rc=0
  : > "$FGC_TRACE"
  bash "$tmp/scripts/maintenance/upgrade-fedora.sh" "$action" > "$tmp/output" 2>&1 || rc=$?
  [[ "$rc" == "$expected" ]] || { cat "$tmp/output"; echo "upgrade fixture rc=$rc expected=$expected" >&2; exit 1; }
}
run_expect 60 prepare
[[ ! -s "$FGC_TRACE" ]]
export FAKE_PROFILE=ready FAKE_VM=true
run_expect 50 prepare
[[ ! -s "$FGC_TRACE" ]]
export FAKE_VM=false FAKE_DIRTY=true
run_expect 50 prepare
[[ ! -s "$FGC_TRACE" ]]
export FAKE_DIRTY=false FAKE_UPDATES_RC=100
run_expect 20 prepare
! grep -Eq 'backup|system-upgrade' "$FGC_TRACE"
export FAKE_UPDATES_RC=0 FAKE_BACKUP_RC=40
run_expect 40 prepare
! grep -Fq system-upgrade "$FGC_TRACE"
[[ ! -e "$tmp/state/fedora45-upgrade.env" ]]
export FAKE_BACKUP_RC=0 FAKE_DOWNLOAD_RC=1
run_expect 1 prepare
[[ ! -e "$tmp/state/fedora45-upgrade.env" ]]
export FAKE_DOWNLOAD_RC=0
run_expect 0 prepare
grep -Fxq 'phase=prepared' "$tmp/state/fedora45-upgrade.env"
grep -Fq -- '--include-vms' "$ROOT/scripts/maintenance/upgrade-fedora.sh"
run_expect 20 finalize
[[ ! -s "$FGC_TRACE" ]]
export FAKE_OS=45
run_expect 20 finalize
[[ ! -s "$FGC_TRACE" ]]
sed -i 's/^commit=.*/commit=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/' "$tmp/state/fedora45-upgrade.env"
run_expect 50 reboot
[[ ! -s "$FGC_TRACE" ]]
echo 'Fedora upgrade guards and preparation behavior: PASS'
