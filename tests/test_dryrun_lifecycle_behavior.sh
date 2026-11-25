#!/usr/bin/env bash
# Exercise the actual install entrypoint with an isolated catalog and identity.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/repo"
mkdir -p "$fixture/lib" "$fixture/state"
cp "$ROOT/install.sh" "$fixture/"
cp "$ROOT/lib/apply_gate.sh" "$ROOT/lib/evidence.sh" "$fixture/lib/"
printf 'install_lock_acquire() { :; }\n' > "$fixture/lib/install_lock.sh"
printf 'apply_incident_require_clear() { :; }\napply_incident_begin() { :; }\napply_incident_close() { :; }\n' > "$fixture/lib/apply_incident.sh"
cat > "$fixture/lib/bootstrap.sh" <<'BOOT'
# Load real libraries before defining fixture overrides: sourcing during
# engine_bootstrap would replace the test's identity and APPLY callbacks.
source "$REPO_ROOT/lib/evidence.sh"
source "$REPO_ROOT/lib/apply_gate.sh"
engine_bootstrap() {
  STATE_ROOT="$REPO_ROOT/state"; LOG_DIR="$STATE_ROOT"; RUN_ID=fixture
  EXIT_SECURITY_BLOCK=50
}
repo_commit() { printf '%040d\n' 1; }
effective_config_sha256() { printf '%064d\n' "$(cat "$REPO_ROOT/state/config")"; }
module_plan_sha256() { printf '%064d\n' 3; }
baseline_fingerprint() { printf 'fixture-hardware\n'; }
runtime_is_baremetal() { return 0; }
is_true() { [[ "$1" == true ]]; }
ui_banner() { :; }
ui_summary() { :; }
ui_error() { echo "$*" >&2; }
module_catalog_load() { :; }
module_catalog_validate() { [[ "${T_SCENARIO:-}" != invalid-catalog ]]; }
apply_gate_require_clean_git() { return 0; }
orchestrator_run_all() {
  [[ ! -e "$STATE_ROOT/dryrun-$(repo_commit).ok" ]] || return 91
  case "${T_SCENARIO:-}" in
    fail) return 37 ;;
    interrupted) exit 37 ;;
    changed) printf '9\n' > "$STATE_ROOT/config" ;;
  esac
}
orchestrator_report() {
  if [[ "${T_SCENARIO:-}" == report-fail ]]; then
    false
  fi
  printf 'fixture report\n'
}
# Other APPLY gates are verified separately in their own real behavior tests.
apply_gate_open() { apply_gate_require_dryrun; }
BOOT
proof="$fixture/state/dryrun-$(printf '%040d' 1).ok"
printf '2\n' > "$fixture/state/config"
run() { bash "$fixture/install.sh" "$@"; }
valid() { run --dry-run; [[ -s "$proof" ]]; }
for scenario in fail interrupted changed report-fail invalid-catalog; do
  printf '2\n' > "$fixture/state/config"
  valid
  if T_SCENARIO="$scenario" run --dry-run; then
    echo "Unexpected dry-run success: $scenario" >&2; exit 1
  fi
  [[ ! -e "$proof" ]] || { echo "Old proof survived: $scenario" >&2; exit 1; }
done
printf '2\n' > "$fixture/state/config"
valid
run --dry-run --collect-all
[[ ! -e "$proof" ]]
valid
run --apply
[[ ! -e "$proof" ]]
if run --apply; then echo 'Consumed proof authorized another APPLY' >&2; exit 1; fi
valid
echo 'Dry-run lifecycle: PASS (failure, interruption, identity drift, report failure, collect-all and consumed proof)'
