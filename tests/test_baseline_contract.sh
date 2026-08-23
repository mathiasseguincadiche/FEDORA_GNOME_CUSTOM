#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for file in "$ROOT"/modules/baseline/*.sh; do
  ! grep -Eq '(run_mutating|dnf[[:space:]].*(install|remove|upgrade)|systemctl[[:space:]].*(enable|disable|start|stop|restart)|sysctl[[:space:]]+-w|grubby|force_probe|pcie_aspm=off|intel_idle\.max_cstate)' "$file" || {
    echo "baseline module contains forbidden mutation/tweak: $file" >&2
    exit 1
  }
done

grep -Fq 'baseline_certification_valid' "$ROOT/lib/apply_gate.sh"
grep -Fq 'baseline_evidence_valid memory-5600' "$ROOT/lib/baseline.sh"
grep -Fq 'baseline_evidence_valid memory-6000' "$ROOT/lib/baseline.sh"
grep -Fq 'baseline_evidence_valid nvme-io' "$ROOT/lib/baseline.sh"
grep -Fq 'BASELINE_MIN_SUSPEND_CYCLES' "$ROOT/lib/baseline.sh"
grep -Fq 'fingerprint=' "$ROOT/lib/baseline.sh"

echo 'baseline contract: PASS'
