#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
trap 'echo "workstation control center contract failed at line $LINENO" >&2' ERR
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || { echo 'VERSION must be semantic x.y.z' >&2; exit 1; }
[[ -f "$ROOT/control.sh" ]] || { echo 'control.sh missing' >&2; exit 1; }
[[ -f "$ROOT/lib/control_center.sh" ]] || { echo 'control center library missing' >&2; exit 1; }
[[ -f "$ROOT/lib/control_center_presentation.sh" ]] || { echo 'control center presentation layer missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/maintenance/update-system.sh" ]] || { echo 'update-system.sh missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/maintenance/prune-project-artifacts.sh" ]] || { echo 'prune-project-artifacts.sh missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/release/seal-golden-archive.sh" ]] || { echo 'seal-golden-archive.sh missing' >&2; exit 1; }
[[ -f "$ROOT/config/operator-retention.policy" ]] || { echo 'operator-retention.policy missing' >&2; exit 1; }
[[ -f "$ROOT/scripts/kernel/kernel-lifecycle.sh" ]] || { echo 'kernel lifecycle entrypoint missing' >&2; exit 1; }

bash -n "$ROOT/control.sh"
bash -n "$ROOT/lib/control_center.sh"
bash -n "$ROOT/lib/control_center_presentation.sh"
bash -n "$ROOT/scripts/maintenance/update-system.sh"
bash -n "$ROOT/scripts/maintenance/prune-project-artifacts.sh"
bash -n "$ROOT/scripts/release/seal-golden-archive.sh"
bash -n "$ROOT/scripts/kernel/kernel-lifecycle.sh"

# The historical menu entrypoint must remain a compatibility alias, not a second implementation.
grep -Fq "exec \"\$REPO_ROOT/control.sh\" \"\$@\"" "$ROOT/menu.sh"
[[ "$(wc -l < "$ROOT/menu.sh")" -le 10 ]] || { echo 'menu.sh should remain a thin alias' >&2; exit 1; }

# Operator surface: ten clear functional pillars plus non-interactive CLI.
for expected in \
  'INSTALLATION & CONVERGENCE' \
  'MISES À JOUR' \
  'SAUVEGARDE & RESTAURATION' \
  'DIAGNOSTICS & SANTÉ' \
  'KERNEL & BOOT' \
  'KVM / MACHINES VIRTUELLES' \
  'PERFORMANCE FEDORA LINUX' \
  'MAINTENANCE' \
  'CERTIFICATION' \
  'LOGS & PREUVES' \
  'NO_COLOR' \
  'cc_cli_dispatch'; do
  grep -Fq "$expected" "$ROOT/lib/control_center.sh" || { echo "control center missing contract: $expected" >&2; exit 1; }
done

# The presentation layer exposes the current Golden vocabulary and mandatory pillars.
grep -Fq 'Politique N / N-1 · max 2' "$ROOT/lib/control_center_presentation.sh"
grep -Fq "cc_option 5 'Kernel & boot' 'latest-stable / N-N-1 / recovery'" "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'Gaming / Steam / Vulkan' "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'Stockage / T705 / data' "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'cc_gaming_state' "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'cc_data_state' "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'control_center_presentation.sh' "$ROOT/control.sh"
grep -Fq 'diagnostics/data-storage-doctor' "$ROOT/control.sh"
grep -Fq 'diagnostics/gaming-doctor' "$ROOT/control.sh"

# The sole supported guest profile is Rocky DevOps. Its parameterized CLI and
# interactive facade both delegate to the same engine.
grep -Fq 'cc_kvm_create_rocky_interactive' "$ROOT/lib/control_center_presentation.sh"
grep -Fq -- '--cloud-image "$cloud_image"' "$ROOT/lib/control_center_presentation.sh"
grep -Fq 'if [[ "${1:-}" == kvm ]]' "$ROOT/control.sh"
grep -Fq 'create-rocky)' "$ROOT/control.sh"
grep -Fq 'shift 2' "$ROOT/control.sh"
grep -Fq 'create_rocky_devops_vm.sh" "$@"' "$ROOT/control.sh"
grep -Fq './control.sh kvm create-rocky --cloud-image PATH' "$ROOT/lib/control_center_presentation.sh"
if grep -Eqi 'create-windows|create_windows11_vm|cc_kvm_create_windows|--windows-iso|--virtio-iso' \
    "$ROOT/control.sh" "$ROOT/lib/control_center.sh" "$ROOT/lib/control_center_presentation.sh"; then
  echo 'removed Windows guest remains available through the Control Center' >&2
  exit 1
fi

# Dashboard truth must be based on real runtime data, not marker presence alone.
grep -Fq 'os_id' "$ROOT/lib/control_center.sh"
grep -Fq "if [[ \"\$os_id\" != fedora ]]; then" "$ROOT/lib/control_center.sh"
grep -Fq 'workstation_runtime_fingerprint' "$ROOT/lib/control_center.sh"
grep -Fq "fingerprint=\$expected" "$ROOT/lib/control_center.sh"
grep -Fq 'STALE' "$ROOT/lib/control_center.sh"

# Thin facade: dangerous business logic must stay in the dedicated engines.
if grep -Eq 'apply_gate_open|dnf5?[[:space:]].*upgrade|flatpak[[:space:]]+update|borg[[:space:]]+(create|prune|compact|delete)|nft[[:space:]]+-f' "$ROOT/lib/control_center.sh" "$ROOT/lib/control_center_presentation.sh"; then
  echo 'business logic leaked into Control Center UI' >&2
  exit 1
fi
if grep -Eq 'apply_gate_open|dnf5?[[:space:]].*upgrade|borg[[:space:]]+(create|prune|compact|delete)' "$ROOT/control.sh"; then
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
grep -Fq 'install-latest|prune|rollback' "$ROOT/control.sh"
grep -Fq 'rollback-fedora' "$ROOT/control.sh"
grep -Fq "\"\$REPO_ROOT/scripts/kvm/kvm_network_guard.sh\" reconcile" "$ROOT/lib/control_center.sh"

# Routine Fedora updates are fail-closed, bare-metal only, backed up first and staged offline.
grep -Fq 'runtime_is_baremetal' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'mandatory_preupdate_backup' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq "\"\$REPO_ROOT/scripts/backup/backup-now.sh\"" "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'kernel_lifecycle_prepare_rolling_update' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'sudo dnf5 --refresh upgrade --offline -y' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'sudo dnf5 offline reboot' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'sudo dnf5 check' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'kernel_lifecycle_finalize_update' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'flatpak update -y' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq "\"\$REPO_ROOT/diagnostic.sh\"" "$ROOT/scripts/maintenance/update-system.sh"

# The operator CLI must expose the complete offline lifecycle without duplicating business logic.
grep -Fq 'update-system.sh" --offline-reboot' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --finalize' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --offline-status' "$ROOT/control.sh"
grep -Fq 'update-system.sh" --offline-log' "$ROOT/control.sh"

# Firmware is query-only from the automated update path.
grep -Fq 'fwupdmgr get-updates' "$ROOT/scripts/maintenance/update-system.sh"
if grep -Eq 'fwupdmgr[[:space:]]+(update|install)' "$ROOT/scripts/maintenance/update-system.sh"; then
  echo 'firmware flashing must never be automated by update-system.sh' >&2
  exit 1
fi

# Golden kernel policy installs latest stable directly and retains only N/N-1.
grep -Fq 'ENABLE_KERNEL_VANILLA_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$ROOT/config/kernel.conf"
grep -Fxq 'mode=rolling-n-nminus1' "$ROOT/config/kernel-lifecycle.policy"
grep -Fxq 'install_latest_direct=true' "$ROOT/config/kernel-lifecycle.policy"
grep -Fxq 'max_installed_kernels=2' "$ROOT/config/kernel-lifecycle.policy"
grep -Fq 'installonly_limit=$dnf_limit' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'kernel_lifecycle_release_nevras "$release"' "$ROOT/lib/kernel_lifecycle.sh"

# Update order: backup must precede preparation of the offline DNF transaction.
python3 - "$ROOT/scripts/maintenance/update-system.sh" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
branch = text.split('  --apply)', 1)[1].split('    ;;', 1)[0]
assert branch.index('mandatory_preupdate_backup') < branch.index('prepare_dnf_offline'), 'backup must precede offline DNF preparation'
PY

# Transient artifact retention is explicit and must never prune Golden evidence.
grep -Fxq 'logs_days=90' "$ROOT/config/operator-retention.policy"
grep -Fxq 'reports_days=180' "$ROOT/config/operator-retention.policy"
grep -Fxq 'preserve_state=true' "$ROOT/config/operator-retention.policy"
grep -Fxq 'preserve_releases=true' "$ROOT/config/operator-retention.policy"
grep -Fq 'prune-project-artifacts.sh" --check' "$ROOT/control.sh"
grep -Fq 'prune-project-artifacts.sh" --apply' "$ROOT/control.sh"
grep -Fq 'state/=preserved' "$ROOT/scripts/maintenance/prune-project-artifacts.sh"
if grep -Eq 'rm .*STATE_ROOT|find .*STATE_ROOT.*-delete' "$ROOT/scripts/maintenance/prune-project-artifacts.sh"; then
  echo 'artifact retention must never delete Golden state' >&2
  exit 1
fi

# Long-term archive sealing requires a current certified release and safe source/destination separation.
grep -Fq 'seal-golden-archive.sh' "$ROOT/control.sh"
grep -Fq 'runtime_is_baremetal' "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq "grep -Fxq 'verdict=PASS'" "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq "fingerprint=\$(workstation_runtime_fingerprint)" "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq "effective_config_sha256=\$(effective_config_sha256)" "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq 'state/releases/' "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq 'Destination must not be inside a payload source' "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq 'MANIFEST.sha256' "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq 'must be stored outside the Git checkout' "$ROOT/scripts/release/seal-golden-archive.sh"
grep -Fq 'The script never downloads external payloads automatically.' "$ROOT/scripts/release/seal-golden-archive.sh"

# Real non-interactive smoke test of the dashboard. It must not require Fedora or bare-metal.
status_file="$(mktemp)"
trap 'rm -f "$status_file"' EXIT
NO_COLOR=1 "$ROOT/control.sh" status > "$status_file"
grep -Fq 'FEDORA GOLDEN WORKSTATION' "$status_file"
grep -Fq 'Projet' "$status_file"
grep -Fq 'Runtime' "$status_file"
grep -Fq 'Politique N / N-1 · max 2' "$status_file"
grep -Fq 'Data' "$status_file"
grep -Fq 'Gaming' "$status_file"
grep -Fq 'Performance' "$status_file"

echo 'workstation control center contract: PASS'
