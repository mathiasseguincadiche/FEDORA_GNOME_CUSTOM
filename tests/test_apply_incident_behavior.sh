#!/usr/bin/env bash
# Exercise real incident persistence and guard across clones; no host mutations.
# shellcheck disable=SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_STATE_HOME="$tmp/shared"
STATE_ROOT="$tmp/clone-a/state"
REPO_ROOT="$tmp/clone-a"
RUN_ID=fixture-one
mkdir -p "$STATE_ROOT"
source "$ROOT/lib/evidence.sh"
source "$ROOT/lib/apply_incident.sh"
apply_gate_require_backup() { [[ "${BACKUP_FIXTURE_OK:-true}" == true ]]; }
marker="$STATE_ROOT/preapply-backup.ok"
printf 'verdict=PASS\narchive=fgc-preapply-original\nsnapshot=%064d\nrepository=/fixture/borg\n' 1 > "$marker"
apply_incident_require_clear
if BACKUP_FIXTURE_OK=false apply_incident_begin; then exit 1; fi
apply_incident_require_clear
apply_incident_begin
active="$(apply_incident_active)"
[[ "$(stat -c %a "$active")" == 600 ]]
grep -Fxq 'archive=fgc-preapply-original' "$active"
# New process / clone, no exit trap: open record remains after interruption.
if bash -c 'source "$1/lib/apply_incident.sh"; apply_incident_require_clear' _ "$ROOT"; then exit 1; fi
REPO_ROOT="$tmp/clone-b"
STATE_ROOT="$REPO_ROOT/state"
RUN_ID=fixture-two
if apply_incident_begin; then exit 1; fi
if apply_incident_close completed; then exit 1; fi
grep -Fxq 'archive=fgc-preapply-original' "$active"
apply_incident_close operator-reviewed
apply_incident_require_clear
history="$(apply_incident_root)/history/fixture-one.marker"
grep -Fxq 'incident_resolution=operator-reviewed' "$history"
grep -Fxq 'archive=fgc-preapply-original' "$history"
# Successful run closes only after completion and keeps original metadata.
mkdir -p "$STATE_ROOT"
cp "$marker" "$STATE_ROOT/preapply-backup.ok"
apply_incident_begin
apply_incident_close completed
apply_incident_require_clear
grep -Fxq 'incident_resolution=completed' "$(apply_incident_root)/history/fixture-two.marker"
ln -s "$tmp/missing" "$active"
if apply_incident_require_clear; then exit 1; fi
rm "$active"
# Never invoke a real Borg prune on a pre-APPLY archive class.
source "$ROOT/lib/backup_runtime.sh"
borg() { echo 'unexpected Borg invocation' >&2; exit 91; }
if backup_engine_prune preapply; then exit 1; fi
# Ensure real entrypoints call the guard in the intended order.
python3 - "$ROOT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
install = (root / "install.sh").read_text().split("DRY_RUN=false; export DRY_RUN", 1)[1]
assert install.index("apply_incident_require_clear") < install.index("apply_gate_open") < install.index("apply_incident_begin") < install.index("orchestrator_run_all") < install.index("apply_incident_close completed")
backup = (root / "prepare-preapply-backup.sh").read_text()
assert backup.index("apply_incident_require_clear") < backup.index("sudo dnf") < backup.index("backup_engine_create preapply")
PY
echo 'APPLY incident persistence and rollback preservation: PASS (fixtures only)'
