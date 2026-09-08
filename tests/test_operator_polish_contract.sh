#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for file in \
  control.sh \
  lib/control_center_operator_polish.sh \
  scripts/maintenance/update-system.sh \
  scripts/maintenance/prune-project-evidence.sh \
  scripts/release/archive-golden-payloads.sh; do
  [[ -f "$ROOT/$file" ]] || { echo "missing operator polish file: $file" >&2; exit 1; }
  bash -n "$ROOT/$file"
done

[[ -f "$ROOT/config/log-retention.policy" ]] || { echo 'missing log retention policy' >&2; exit 1; }
[[ -f "$ROOT/docs/GOLDEN_PAYLOAD_ARCHIVE.md" ]] || { echo 'missing Golden payload archive documentation' >&2; exit 1; }

# Complete update lifecycle is exposed through control.sh while business logic
# remains delegated to the dedicated update engine.
grep -Fq 'update-system.sh" --offline-reboot' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --finalize' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --offline-status' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --offline-log' "$ROOT/control.sh"
grep -Fq -- '--finalize|--post-offline)' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'Compatibility alias for --finalize' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq './control.sh update reboot' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq './control.sh update finalize' "$ROOT/docs/CONTROL_CENTER.md"

# Interactive menu exposes the same continuation steps.
grep -Fq -- '--offline-reboot' "$ROOT/lib/control_center_operator_polish.sh"
grep -Fq -- '--finalize' "$ROOT/lib/control_center_operator_polish.sh"

# Retention is conservative: state/releases remain outside deletion roots,
# references from state protect ordinary logs/reports, and dry-run is explicit.
grep -Fxq 'log_retention_days=90' "$ROOT/config/log-retention.policy"
grep -Fxq 'report_retention_days=365' "$ROOT/config/log-retention.policy"
grep -Fxq 'protect_state=true' "$ROOT/config/log-retention.policy"
grep -Fxq 'protect_releases=true' "$ROOT/config/log-retention.policy"
grep -Fxq 'protect_referenced=true' "$ROOT/config/log-retention.policy"
grep -Fq 'is_state_referenced' "$ROOT/scripts/maintenance/prune-project-evidence.sh"
grep -Fq 'state/ is never deleted' "$ROOT/scripts/maintenance/prune-project-evidence.sh"
grep -Fq 'state/releases/ is never deleted' "$ROOT/scripts/maintenance/prune-project-evidence.sh"
grep -Fq 'prune-apply)' "$ROOT/control.sh"
grep -Fq './control.sh logs prune-apply' "$ROOT/docs/CONTROL_CENTER.md"
if grep -Eq 'rm[[:space:]].*STATE_ROOT|rm[[:space:]].*state/releases' "$ROOT/scripts/maintenance/prune-project-evidence.sh"; then
  echo 'retention helper must never delete Golden state/releases' >&2
  exit 1
fi

# Long-term payload archive must be explicit, external, checksum-bound and
# dependent on a real Golden PASS marker.
grep -Fq "\$STATE_ROOT/final/certified.ok" "$ROOT/scripts/release/archive-golden-payloads.sh"
grep -Fq "grep -Fxq 'verdict=PASS'" "$ROOT/scripts/release/archive-golden-payloads.sh"
grep -Fq 'Payload archive must live outside the Git checkout' "$ROOT/scripts/release/archive-golden-payloads.sh"
grep -Fq 'PAYLOADS.sha256' "$ROOT/scripts/release/archive-golden-payloads.sh"
grep -Fq 'METADATA.sha256' "$ROOT/scripts/release/archive-golden-payloads.sh"
grep -Fq 'ne télécharge rien' "$ROOT/docs/GOLDEN_PAYLOAD_ARCHIVE.md"

# Safe smoke surfaces that do not mutate a workstation.
bash "$ROOT/scripts/release/archive-golden-payloads.sh" --help >/dev/null
bash "$ROOT/scripts/maintenance/prune-project-evidence.sh" --dry-run >/dev/null

echo 'operator polish contract: PASS'
