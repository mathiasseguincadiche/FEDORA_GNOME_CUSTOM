#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in "$ROOT"/modules/baseline/*.sh; do
  ! grep -Eq '(run_mutating|dnf[[:space:]].*(install|remove|upgrade)|systemctl[[:space:]].*(enable|disable|start|stop|restart)|sysctl[[:space:]]+-w|grubby)' "$file" || { echo "baseline module contains forbidden mutation command: $file" >&2; exit 1; }
done
grep -Fq 'baseline_certification_valid' "$ROOT/lib/apply_gate.sh"
for evidence in memory-5600 memory-6000 nvme-root nvme-data; do grep -Fq "baseline_evidence_valid $evidence" "$ROOT/lib/baseline.sh" || { echo "missing baseline evidence contract: $evidence" >&2; exit 1; }; done
grep -Fq 'automated=true' "$ROOT/diagnostics/baseline-doctor"
grep -Fq 'stress-ng' "$ROOT/diagnostics/baseline-doctor"
grep -Fq 'fio --name=' "$ROOT/diagnostics/baseline-doctor"
grep -Fq 'root and /data must be backed by two distinct physical NVMe devices' "$ROOT/lib/baseline.sh"
grep -Fq 'BASELINE_MIN_SUSPEND_CYCLES="0"' "$ROOT/config/baseline.conf"
grep -Fq 'certified after APPLY/reboot' "$ROOT/diagnostics/baseline-doctor"
echo 'baseline contract: PASS'
