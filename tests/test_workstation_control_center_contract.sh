#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$(tr -d '[:space:]' < "$ROOT/VERSION")" == "0.14.0" ]] || { echo 'VERSION must be 0.14.0' >&2; exit 1; }
[[ -f "$ROOT/control.sh" ]] || { echo 'control.sh missing' >&2; exit 1; }
[[ -f "$ROOT/lib/control_center.sh" ]] || { echo 'control center library missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/maintenance/update-system.sh" ]] || { echo 'update-system.sh missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/kernel/kernel-lifecycle.sh" ]] || { echo 'kernel lifecycle entrypoint missing' >&2; exit 1; }
[[ -f "$ROOT/docs/CONTROL_CENTER.md" ]] || { echo 'CONTROL_CENTER.md missing' >&2; exit 1; }

bash -n "$ROOT/control.sh"
bash -n "$ROOT/lib/control_center.sh"
bash -n "$ROOT/scripts/maintenance/update-system.sh"
bash -n "$ROOT/scripts/kernel/kernel-lifecycle.sh"

# The historical menu entrypoint must remain a compatibility alias, not a second implementation.
grep -Fq "exec \"\$REPO_ROOT/control.sh\" \"\$@\"" "$ROOT/menu.sh"
[[ "$(wc -l < "$ROOT/menu.sh")" -le 10 ]] || { echo 'menu.sh should remain a thin alias' >&2; exit 1; }

# Operator surface: nine clear functional pillars plus non-interactive CLI.
for expected in \
  'INSTALLATION & CONVERGENCE' \
  'MISES À JOUR' \
  'SAUVEGARDE & RESTAURATION' \
  'DIAGNOSTICS & SANTÉ' \
  'KERNEL & BOOT' \
  'KVM / MACHINES VIRTUELLES' \
  'MAINTENANCE' \
  'CERTIFICATION' \
  'LOGS & PREUVES' \
  'NO_COLOR' \
  'cc_cli_dispatch'; do
  grep -Fq "$expected" "$ROOT/lib/control_center.sh" || { echo "control center missing contract: $expected" >&2; exit 1; }
done

# Dashboard truth must be based on real runtime data, not marker presence alone.
grep -Fq 'os_id' "$ROOT/lib/control_center.sh"
grep -Fq "if [[ \"\$os_id\" != fedora ]]; then" "$ROOT/lib/control_center.sh"
grep -Fq 'workstation_runtime_fingerprint' "$ROOT/lib/control_center.sh"
grep -Fq "fingerprint=\$expected" "$ROOT/lib/control_center.sh"
grep -Fq 'STALE' "$ROOT/lib/control_center.sh"

# Thin facade: dangerous business logic must stay in the dedicated engines.
if grep -Eq 'apply_gate_open|dnf[[:space:]]+upgrade|flatpak[[:space:]]+update|restic[[:space:]]+backup|nft[[:space:]]+-f' "$ROOT/lib/control_center.sh"; then
  echo 'business logic leaked into control_center.sh' >&2
  exit 1
fi
if grep -Eq 'apply_gate_open|dnf[[:space:]]+upgrade|restic[[:space:]]+backup' "$ROOT/control.sh"; then
  echo 'business logic leaked into control.sh' >&2
  exit 1
fi

# Existing protected engines must be called, not bypassed.
grep -Fq "\"\$REPO_ROOT/install.sh\" --dry-run" "$ROOT/lib/control_center.sh"
grep -Fq "\"\$REPO_ROOT/install.sh\" --apply" "$ROOT/lib/control_center.sh"
grep -Fq "\"\$REPO_ROOT/prepare-preapply-backup.sh\"" "$ROOT/lib/control_center.sh"
grep -Fq "\"\$REPO_ROOT/scripts/backup/restore.sh\" restore" "$ROOT/lib/control_center.sh"
grep -Fq "backup-now.sh\" --prune" "$ROOT/lib/control_center.sh"
grep -Fq "\"\$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh\"" "$ROOT/lib/control_center.sh"
grep -Fq 'scripts/kernel/kernel-lifecycle.sh' "$ROOT/control.sh"
grep -Fq 'candidate|boot-candidate|certify|rollback' "$ROOT/control.sh"
grep -Fq 'rollback-fedora' "$ROOT/control.sh"
grep -Fq "\"\$REPO_ROOT/scripts/kvm/kvm_network_guard.sh\" reconcile" "$ROOT/lib/control_center.sh"

# Full update is fail-closed around a real Restic system backup and remains bare-metal only.
grep -Fq 'runtime_is_baremetal' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'mandatory_preupdate_backup' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq "\"\$REPO_ROOT/scripts/backup/backup-now.sh\"" "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'sudo dnf upgrade --refresh -y' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'flatpak update -y' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq "\"\$REPO_ROOT/diagnostic.sh\"" "$ROOT/scripts/maintenance/update-system.sh"

# Firmware is query-only from the automated update path.
grep -Fq 'fwupdmgr get-updates' "$ROOT/scripts/maintenance/update-system.sh"
if grep -Eq 'fwupdmgr[[:space:]]+(update|install)' "$ROOT/scripts/maintenance/update-system.sh"; then
  echo 'firmware flashing must never be automated by update-system.sh' >&2
  exit 1
fi

# Golden kernel policy is candidate -> certified, with Fedora fallback retained.
grep -Fq 'ENABLE_KERNEL_VANILLA_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_LIFECYCLE_MODE="candidate-certified"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="false"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$ROOT/config/kernel.conf"

# Update order: backup must appear before DNF in the protected full-update branch.
python3 - "$ROOT/scripts/maintenance/update-system.sh" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
branch = text.split('  --apply)', 1)[1].split('    ;;', 1)[0]
assert branch.index('mandatory_preupdate_backup') < branch.index('apply_dnf'), 'backup must precede DNF'
PY

# Real non-interactive smoke test of the dashboard. It must not require Fedora or bare-metal.
status_file="$(mktemp)"
trap 'rm -f "$status_file"' EXIT
NO_COLOR=1 "$ROOT/control.sh" status > "$status_file"
grep -Fq 'FEDORA GOLDEN WORKSTATION' "$status_file"
grep -Fq 'Projet' "$status_file"
grep -Fq 'Runtime' "$status_file"
grep -Fq 'vanilla/stable latest-stable' "$status_file"

# Documentation must explain both interactive and CLI use and the no-auto-flash rule.
grep -Fq './control.sh' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq './control.sh update all' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq './control.sh kernel candidate' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq './control.sh kernel certify' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq 'aucun flash' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq 'kernel-vanilla/stable' "$ROOT/docs/CONTROL_CENTER.md"

echo 'workstation control center contract: PASS'
