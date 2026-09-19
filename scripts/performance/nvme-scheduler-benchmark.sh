#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/performance_runtime.sh"
source "$REPO_ROOT/lib/persistent_data.sh"
runtime_is_baremetal || { ui_error 'NVMe scheduler benchmark is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
[[ "$(performance_policy_get nvme_policy)" == benchmark-only ]] || { ui_error 'NVMe policy is not benchmark-only'; exit "$EXIT_CONFIG_FAILED"; }
[[ "$(performance_policy_get allow_experimental_io_scheduler)" == false ]] || { ui_error 'Experimental I/O schedulers are forbidden by Golden policy'; exit "$EXIT_SECURITY_BLOCK"; }
command -v fio >/dev/null 2>&1 || { ui_error 'fio is required'; exit "$EXIT_PRECHECK_FAILED"; }
persistent_data_validate_mount || { ui_error '/data must be the dedicated persistent T705 EXT4 mount'; exit "$EXIT_PRECHECK_FAILED"; }
source_dev="$(findmnt -no SOURCE "${EXPECTED_DATA_MOUNT:-/data}")"
base="$(lsblk -no PKNAME "$source_dev" 2>/dev/null | head -n1)"
[[ -n "$base" ]] || base="$(basename "$source_dev")"
sched_file="/sys/block/$base/queue/scheduler"
[[ -r "$sched_file" ]] || { ui_error "Scheduler control unavailable: $sched_file"; exit "$EXIT_PRECHECK_FAILED"; }
model="$(xargs < "/sys/block/$base/device/model" 2>/dev/null || true)"
[[ "$model" == *CT1000T705SSD3* ]] || { ui_error "Refusing benchmark on non-target NVMe model: ${model:-unknown}"; exit "$EXIT_SECURITY_BLOCK"; }
original="$(sed -nE 's/.*\[([^]]+)\].*/\1/p' "$sched_file")"
[[ -n "$original" ]] || { ui_error 'Unable to resolve active scheduler'; exit "$EXIT_PRECHECK_FAILED"; }
restore(){ printf '%s\n' "$original" | sudo tee "$sched_file" >/dev/null 2>&1 || true; rm -f "${scratch:-}"; }
trap restore EXIT INT TERM
available="$(cat "$sched_file")"
report="$REPORT_ROOT/$RUN_ID-nvme-scheduler-benchmark.txt"
: > "$report"
for scheduler in none mq-deadline; do
  grep -qw "$scheduler" <<<"$available" || continue
  printf '%s\n' "$scheduler" | sudo tee "$sched_file" >/dev/null
  scratch="${EXPECTED_DATA_MOUNT:-/data}/.fgc-nvme-scheduler-benchmark.$$"
  json="$REPORT_ROOT/$RUN_ID-nvme-$scheduler.json"
  fio --name="fgc-$scheduler" --filename="$scratch" --size=2G --runtime=20 --time_based --direct=1 --rw=randrw --rwmixread=70 --bs=4k --iodepth=32 --ioengine=io_uring --group_reporting --output-format=json --output="$json"
  rm -f "$scratch"; scratch=''
  python3 - "$scheduler" "$json" >> "$report" <<'PY'
import json, sys
name,path=sys.argv[1:]
d=json.load(open(path,encoding='utf-8'))['jobs'][0]
print(f"scheduler={name}")
for op in ('read','write'):
    x=d[op]
    print(f"{op}_iops={x.get('iops',0):.2f}")
    print(f"{op}_bw_kib_s={x.get('bw',0)}")
    ns=x.get('clat_ns',{}).get('percentile',{})
    for p in ('95.000000','99.000000','99.900000'):
        if p in ns: print(f"{op}_clat_{p}_ns={ns[p]}")
PY
done
cat "$report"
