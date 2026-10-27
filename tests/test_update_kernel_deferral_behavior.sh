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
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/logs" "$tmp/reports" "$tmp/state"

# Fake privileged tools: record every DNF5 call, never touch the system.
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == 'test -e /usr/lib/sysimage/libdnf5/offline/transaction.json' ]]; then
  [[ "${T_PENDING:-false}" == true || -e "$T_STATE.staged" ]]; exit $?
fi
exec "$@"
SH
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DNF_LOG"
if [[ "$*" == *'upgrade --offline'* && "${T_NO_PLAN:-false}" != true ]]; then touch "$T_STATE.staged"; fi
if [[ "$*" == 'history info 1..last --json' ]]; then
  python3 - "$T_STATE" "${T_HISTORY:-good}" <<'PYH'
import json,sys
state=dict(line.strip().split('=',1) for line in open(sys.argv[1]))
row=dict(id=42, start_time=int(state['prepared_timestamp']), end_time=int(state['prepared_timestamp'])+1,
         status='Ok', description='dnf5 upgrade --offline --comment='+state['transaction_comment'])
if sys.argv[2] == 'old': row['description']='dnf5 upgrade --offline --comment=old'
if sys.argv[2] == 'failed': row['status']='Error'
print(json.dumps([row]))
PYH
fi
exit 0
SH
cat > "$tmp/bin/flatpak" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FLATPAK_LOG"
[[ "$*" == 'update -y' ]] || exit 99
(( ${T_FLATPAK_RC:-0} == 0 )) || exit "$T_FLATPAK_RC"
rm -f "$FLATPAK_PENDING"
SH
chmod +x "$tmp/bin/"*

# run_update <scenario rc of kernel resolution> <action...>
run_update() {
  local kernel_rc="$1"; shift
  (
    export PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/runtime" DNF_LOG="$tmp/dnf.log" RUN_ID="deferral-$RANDOM"
    export FLATPAK_LOG="$tmp/flatpak.log" FLATPAK_PENDING="$tmp/flatpak-pending"
    # Keep diagnostic output inside the fixture even with a read-only checkout.
    STATE_ROOT="$tmp/state"; REPORT_ROOT="$tmp/reports"; LOG_DIR="$tmp/logs"; MAIN_LOG="$LOG_DIR/main.log"
    # Load every function of the real entrypoint, without its final dispatcher.
    # shellcheck disable=SC1090
    source <(sed -e 's/^engine_bootstrap$/engine_load_libraries; config_load/' -e '/^mode="\${1:---check}"$/,$d' \
      -e "s|^REPO_ROOT=.*|REPO_ROOT='$ROOT'|" "$ROOT/scripts/maintenance/update-system.sh")
    UPDATE_STATE_FILE="$tmp/update.status"
    export T_STATE="$UPDATE_STATE_FILE"
    boot_id=00000000-0000-4000-8000-000000000001
    update_current_boot_id() { echo "$boot_id"; }
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
      if (( kernel_rc == 0 )); then
        if [[ "${T_NO_PLAN:-false}" == true ]]; then
          kernel_lifecycle_latest_installed
        else
          echo '7.2.10-200.vanilla.fc44.x86_64'
        fi
        return 0
      fi
      return "$kernel_rc"
    }
    capture_offline_log() { :; }
    check_firmware() { :; }
    mkdir -p "$tmp/fake-root/scripts/maintenance"
    cp "$ROOT/scripts/maintenance/verify-offline-history.py" "$tmp/fake-root/scripts/maintenance/"
    # shellcheck disable=SC2016 # evaluated by the disposable diagnostic process
    printf '#!/usr/bin/env bash\nexit "${T_DOCTOR_RC:-0}"\n' > "$tmp/fake-root/diagnostic.sh"
    chmod +x "$tmp/fake-root/diagnostic.sh"
    for action in "$@"; do
      case "$action" in
        prepare) prepare_dnf_offline dnf-only ;;
        prepare-full) REPO_ROOT="$tmp/fake-root"; prepare_dnf_offline full ;;
        reboot) request_offline_reboot ;;
        newboot) boot_id=00000000-0000-4000-8000-000000000002; rm -f "$T_STATE.staged" ;;
        finalize) REPO_ROOT="$tmp/fake-root"; finalize_offline_update ;;
      esac
    done
  ) > "$tmp/out.log" 2>&1
}
state() { awk -F= -v k="$1" '$1==k {print $2}' "$tmp/update.status"; }
reset() { rm -f "$tmp/dnf.log" "$tmp/update.status" "$tmp/update.status.staged" "$tmp/pinned" "$tmp/finalized" "$tmp/flatpak.log" "$tmp/flatpak-pending"; }

# 1. Packaging pending / kernel.org unreachable: everything except the kernel.
reset
run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare reboot newboot finalize || fail "deferred update failed: $(tail -5 "$tmp/out.log")"
grep -Eq -- '^--refresh upgrade --offline -y --comment=fgc-offline-[0-9a-f-]{36} --exclude=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra$' "$tmp/dnf.log" \
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
grep -Eq -- '^--refresh upgrade --offline -y --comment=fgc-offline-[0-9a-f-]{36}$' "$tmp/dnf.log" || fail "unexpected transaction: $(cat "$tmp/dnf.log")"
[[ "$(cat "$tmp/pinned")" == 7.2.10-200.vanilla.fc44.x86_64 && "$(state kernel_deferred)" == false ]] || fail 'normal kernel target not pinned'

# A previous offline journal and a clean packagedb cannot prove this update ran.
for scenario in same-boot staged old-history failed-history; do
  reset
  rc=0
  case "$scenario" in
    same-boot) run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare finalize || rc=$? ;;
    staged) T_PENDING=true run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare newboot finalize || rc=$? ;;
    old-history) T_HISTORY=old run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare newboot finalize || rc=$? ;;
    failed-history) T_HISTORY=failed run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare newboot finalize || rc=$? ;;
  esac
  [[ "$rc" != 0 && "$(state phase)" != completed ]] || fail "false completion: $scenario"
done
reset
T_NO_PLAN=true run_update "$EXIT_KERNEL_DEFERRED_TEST" prepare
[[ "$(state phase)" == no-transaction && "$(state reboot_required)" == false ]] || fail 'no-op request was marked prepared or completed'

# RPMs already current: complete the pending Flatpak update without an offline
# reboot. Exercise the real apply_flatpak function, not a replacement helper.
reset
touch "$tmp/flatpak-pending"
T_NO_PLAN=true run_update 0 prepare-full || fail "Flatpak-only full update failed: $(tail -5 "$tmp/out.log")"
[[ "$(cat "$tmp/flatpak.log")" == 'update -y' && ! -e "$tmp/flatpak-pending" ]] || fail 'pending Flatpak update was ignored'
[[ "$(state phase)" == completed && "$(state mode)" == full && "$(state reboot_required)" == false && "$(state doctor_rc)" == 0 ]] || fail 'full update state is not complete without reboot'
grep -Fq 'NO OFFLINE REBOOT REQUIRED' "$tmp/out.log" || fail 'full update summary incorrectly requests an offline reboot'
if grep -Eq '^offline (reboot|log)' "$tmp/dnf.log"; then fail 'no-transaction update attempted offline operations'; fi
rc=0
run_update 0 reboot || rc=$?
[[ "$rc" == 20 ]] || fail 'completed Flatpak update allowed an offline reboot'

# A staged full update still waits for its exact offline transaction before
# updating Flatpak, then executes that update once during finalization.
reset
touch "$tmp/flatpak-pending"
run_update 0 prepare-full || fail 'staged full update failed'
[[ ! -e "$tmp/flatpak.log" && -e "$tmp/flatpak-pending" && "$(state phase)" == prepared ]] || fail 'Flatpak ran before the staged RPM transaction'
run_update 0 newboot finalize || fail 'staged full update did not finalize'
[[ "$(cat "$tmp/flatpak.log")" == 'update -y' && ! -e "$tmp/flatpak-pending" && "$(state phase)" == completed ]] || fail 'staged full update did not update Flatpak exactly once'

# Errors from Flatpak and the global diagnostic must stay failures, including
# when the caller captures the function status with a conditional.
for scenario in flatpak doctor; do
  reset
  touch "$tmp/flatpak-pending"
  rc=0
  if [[ "$scenario" == flatpak ]]; then
    T_NO_PLAN=true T_FLATPAK_RC=33 run_update 0 prepare-full || rc=$?
    [[ "$rc" == 33 && -e "$tmp/flatpak-pending" && "$(state doctor_rc)" == 33 ]] || fail 'Flatpak failure was hidden'
  else
    T_NO_PLAN=true T_DOCTOR_RC=41 run_update 0 prepare-full || rc=$?
    [[ "$rc" == 40 && "$(state doctor_rc)" == 41 ]] || fail 'post-update diagnostic failure was hidden'
  fi
  [[ "$(state phase)" == failed && "$(state reboot_required)" == false ]] || fail "incorrect failed state: $scenario"
done
echo 'update kernel deferral and exact offline completion behavior: PASS'
