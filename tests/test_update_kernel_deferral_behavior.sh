#!/usr/bin/env bash
# Behavioral test of scripts/maintenance/update-system.sh: when kernel.org is
# unreachable or the kernel RPM lags behind it, ONLY the kernel is deferred:
# every other package is still updated, the kernel packages are excluded from
# the DNF transaction, and the deferral survives reboot and finalization.
# Any other kernel failure still blocks the whole update.
# shellcheck disable=SC2030,SC2031,SC2317,SC2034,SC2329
set -Eeuo pipefail
EXIT_KERNEL_DEFERRED_TEST=75
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "update kernel deferral behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/runtime"

# Fake privileged tools: record every DNF5 call, never touch the system.
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DNF_LOG"
exit 0
SH
chmod +x "$tmp/bin/"*

# run_update <scenario rc of kernel resolution> <action...>
run_update() {
  local kernel_rc="$1"; shift
  (
    export PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/runtime" DNF_LOG="$tmp/dnf.log" RUN_ID="deferral-$RANDOM"
    # Load every function of the real entrypoint, without its final dispatcher.
    # shellcheck disable=SC1090
    source <(sed -e '/^mode="\${1:---check}"$/,$d' \
      -e "s|^REPO_ROOT=.*|REPO_ROOT='$ROOT'|" "$ROOT/scripts/maintenance/update-system.sh")
    UPDATE_STATE_FILE="$tmp/update.status"
    KERNEL_DEFER_WHEN_UNAVAILABLE="${T_DEFER:-true}"
    require_dnf5() { :; }
    # Identity is pinned so the finalize step can use a stub diagnostic root.
    repo_commit() { echo 0123456789abcdef0123456789abcdef01234567; }
    effective_config_sha256() { echo fixture-config; }
    kernel_lifecycle_latest_installed() { echo '7.2.9-200.vanilla.fc44.x86_64'; }
    kernel_lifecycle_previous_installed() { echo '7.2.8-200.vanilla.fc44.x86_64'; }
    kernel_lifecycle_lock_hash() { echo lockhash; }
    kernel_lifecycle_pin_target() { echo "$1" > "$tmp/pinned"; }
    kernel_lifecycle_finalize_update() { [[ "$1" == none ]] || echo "$1" > "$tmp/finalized"; }
    kernel_lifecycle_prepare_rolling_update() {
      if (( kernel_rc == 0 )); then echo '7.2.10-200.vanilla.fc44.x86_64'; return 0; fi
      return "$kernel_rc"
    }
    capture_offline_log() { :; }
    check_firmware() { :; }
    for action in "$@"; do
      case "$action" in
        prepare) prepare_dnf_offline dnf-only ;;
        reboot) request_offline_reboot ;;
        finalize) REPO_ROOT="$tmp/fake-root"; mkdir -p "$REPO_ROOT"; printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO_ROOT/diagnostic.sh"; chmod +x "$REPO_ROOT/diagnostic.sh"; finalize_offline_update ;;
      esac
    done
  ) > "$tmp/out.log" 2>&1
}
state() { awk -F= -v k="$1" '$1==k {print $2}' "$tmp/update.status"; }
reset() { rm -f "$tmp/dnf.log" "$tmp/update.status" "$tmp/pinned" "$tmp/finalized"; }

# 1. Packaging pending / kernel.org unreachable: everything except the kernel.
reset
run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare reboot finalize || fail "deferred update failed: $(tail -5 "$tmp/out.log")"
grep -Fxq -- '--refresh upgrade --offline -y --exclude=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra' "$tmp/dnf.log" \
  || fail "kernel packages not excluded from the transaction: $(cat "$tmp/dnf.log")"
[[ ! -e "$tmp/pinned" && ! -e "$tmp/finalized" ]] || fail 'a deferred kernel was pinned or finalized'
[[ "$(state kernel_target)" == none && "$(state kernel_deferred)" == true ]] || fail 'deferral not recorded'
[[ "$(state phase)" == completed ]] || fail "deferral lost across reboot/finalize: phase=$(state phase)"
grep -Fq 'UPDATE COMPLETED (KERNEL DEFERRED)' "$tmp/out.log" || fail 'final summary hides the pending kernel'

# 2. The owner can keep the strict policy: then nothing is updated.
reset
rc=0; T_DEFER=false run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare || rc=$?
[[ "$rc" -eq "$EXIT_KERNEL_DEFERRED_TEST" && ! -s "$tmp/dnf.log" ]] || fail "strict policy did not block (rc=$rc)"

# 3. Any other kernel failure (here a security block) still stops everything.
reset
rc=0; run_update 50 prepare || rc=$?
[[ "$rc" -eq 50 && ! -s "$tmp/dnf.log" ]] || fail "security block was deferred instead of stopping the update (rc=$rc)"

# 4. Normal case: the kernel target is pinned, nothing is excluded.
reset
run_update 0 prepare || fail "normal update failed: $(tail -5 "$tmp/out.log")"
grep -Fxq -- '--refresh upgrade --offline -y' "$tmp/dnf.log" || fail "unexpected transaction: $(cat "$tmp/dnf.log")"
[[ "$(cat "$tmp/pinned")" == 7.2.10-200.vanilla.fc44.x86_64 && "$(state kernel_deferred)" == false ]] || fail 'normal kernel target not pinned'

echo 'update kernel deferral behavior: PASS'
