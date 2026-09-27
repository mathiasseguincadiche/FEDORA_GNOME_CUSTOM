#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reports"
# Run the production probe in a separate Bash process, with only physical I/O
# and sudo mocked. No write is ever made to / or a block device in this test.
python3 - "$ROOT/diagnostics/baseline-doctor" "$tmp/probe.sh" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
start=source.index('run_nvme() (')
end=source.index('\n\ncase ',start)
Path(sys.argv[2]).write_text('set -Eeuo pipefail\n'+source[start:end]+'\nrun_nvme root\n')
PY
cat > "$tmp/adapter.sh" <<'SH_ADAPTER'
set -Eeuo pipefail
REPORT_ROOT="$PROBE_TMP/reports"; RUN_ID="$PROBE_RESULT"
EXIT_USAGE=2; EXIT_PRECHECK_FAILED=20
require_baremetal() { :; }
command_exists() { :; }
mountpoint() { :; }
mount_source_device() { printf '/dev/nvme0n1\n'; }
ui_check() { :; }
ui_error() { echo "$*" >&2; }
baseline_write_evidence() { touch "$PROBE_TMP/evidence"; }
sudo() {
  case "$1" in
    mktemp) mktemp -d "$PROBE_TMP/scratch.XXXXXX" ;;
    chown) return 0 ;;
    rm) [[ "${4:-}" == "$PROBE_TMP"/scratch.* ]] || exit 99; rm -rf -- "$4" ;;
    *) exit 99 ;;
  esac
}
fio() {
  if [[ "$PROBE_RESULT" == failed ]]; then return 42; fi
  echo 'fio fixture verified'
}
source "$PROBE_TMP/probe.sh"
SH_ADAPTER
rc=0
PROBE_TMP="$tmp" PROBE_RESULT=failed bash "$tmp/adapter.sh" || rc=$?
[[ "$rc" == 42 && ! -e "$tmp/evidence" ]]
[[ -z "$(find "$tmp" -name 'scratch.*' -print -quit)" ]]
PROBE_TMP="$tmp" PROBE_RESULT=passed bash "$tmp/adapter.sh"
[[ -f "$tmp/evidence" ]]
[[ -z "$(find "$tmp" -name 'scratch.*' -print -quit)" ]]
echo 'NVMe file probe error propagation and cleanup: PASS'
