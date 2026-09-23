#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2034,SC2030,SC2031,SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
is_true() { [[ "${1,,}" == true ]]; }
command_exists() { command -v "$1" >/dev/null; }
assert_fails() { if "$@"; then echo "Unexpected success: $*" >&2; exit 1; fi; }

# First failing command, nested helper, command substitution and premature exit.
mkdir -p "$tmp/runner/lib" "$tmp/runner/logs"
cat > "$tmp/runner/lib/bootstrap.sh" <<'BOOT'
engine_bootstrap() { :; }
ui_check() { :; }
BOOT
(
  REPO_ROOT="$tmp/runner"
  export MODULE_LOG="$tmp/runner/modules.log"
  LOG_DIR="$tmp/runner/logs"
  declare -A CATALOG_PATH=([regression.module]='module.sh')
  declare -A CATALOG_SCOPE=([regression.module]=TEST)
  source "$ROOT/lib/orchestrator.sh"
  for body in 'bash -c "exit 42"; touch "$REPO_ROOT/continued"' \
    'helper() { bash -c "exit 42"; true; }; helper; true' \
    'value=$(bash -c "exit 42"; echo masked); true' 'exit 0'; do
    cat > "$REPO_ROOT/module.sh" <<EOF
regression_module_precheck() { :; }
regression_module_plan() { :; }
regression_module_apply() { $body; }
regression_module_postcheck() { touch "\$REPO_ROOT/postcheck"; }
EOF
    rc=0
    orchestrator_run_module regression.module || rc=$?
    [[ "$rc" == 42 || ( "$body" == 'exit 0' && "$rc" == 40 ) ]]
    [[ ! -e "$REPO_ROOT/continued" && ! -e "$REPO_ROOT/postcheck" ]]
    [[ "${ORCH_RESULTS[-1]}" == KO\|* ]]
  done
)

# Value-only stdout and stable-release syntax; infrastructure failures propagate.
(
  source "$ROOT/lib/kernel_lifecycle.sh"
  kernel_lifecycle_require_host_gate() { echo 'host checked'; }
  kernel_lifecycle_ensure_tooling_and_repo() { echo 'installed'; }
  kernel_lifecycle_ensure_dnf_retention() { echo 'retention changed'; }
  kernel_lifecycle_resolve_latest_stable() { echo '7.2.2-1.vanilla.x86_64'; }
  [[ "$(kernel_lifecycle_prepare_rolling_update 2>/dev/null)" == 7.2.2-1.vanilla.x86_64 ]]
  assert_fails kernel_lifecycle_release_is_stable $'log\n7.2.2-1.vanilla.x86_64'
  assert_fails kernel_lifecycle_release_is_stable '7.3.0-rc1.vanilla.x86_64'
  kernel_lifecycle_ensure_tooling_and_repo() { return 42; }
  rc=0; kernel_lifecycle_prepare_rolling_update >/dev/null 2>&1 || rc=$?
  [[ "$rc" == 42 ]]
)

# Ordinary lspci output has adjacent devices, with no blank record separator.
(
  source "$ROOT/lib/hardware_platform.sh"
  source "$ROOT/lib/driver_contract.sh"
  lspci() { cat <<'PCI'
0000:00:00.0 Host bridge [0600]: AMD [1022:14d8]
	Kernel driver in use: pcieport
0000:05:00.0 Network controller [0280]: Qualcomm WCN785x [17cb:1107]
	Kernel driver in use: ath12k_pci
0000:06:00.0 Ethernet controller [0200]: Realtek [10ec:8126]
	Kernel driver in use: wrong_driver
0000:07:00.0 USB controller [0c03]: AMD [1022:15b6]
	Kernel driver in use: xhci_hcd
0000:08:00.0 OTHER [0000]: [1111:2222]
	Kernel driver in use: r8169
PCI
  }
  [[ "$(hardware_platform_wifi_identity_value pci_id)" == 17cb:1107 ]]
  [[ "$(hardware_platform_wifi_identity_value driver)" == ath12k_pci ]]
  assert_fails driver_contract_lspci_block_uses 'Ethernet controller' r8169
  driver_contract_lspci_block_uses 'USB controller' xhci_hcd
)

# Missing planned packages must not fail a non-mutating dry run.
(
  EXIT_POSTCHECK_FAILED=40
  DRY_RUN=true
  source "$ROOT/modules/backup/52_repository.sh"
  source "$ROOT/modules/backup/54_kvm_metadata.sh"
  command_exists() { return 1; }
  backup_repository_postcheck
  backup_kvm_precheck
  DRY_RUN=false
  assert_fails backup_repository_postcheck
  assert_fails backup_kvm_precheck
)

# Bootstrapping a nested entrypoint preserves its parent's logs.
(
  REPO_ROOT="$tmp/logging"
  RUN_ID=nested
  source "$ROOT/lib/logging.sh"
  logging_init
  printf 'parent evidence\n' >> "$MAIN_LOG"
  logging_init
  grep -Fxq 'parent evidence' "$MAIN_LOG"
)

# Re-apply the same source SHA after changing repository or retention settings.
(
  REPO_ROOT="$ROOT"; HOME="$tmp/home"
  EXIT_APPLY_FAILED=30
  source "$ROOT/modules/backup/60_daily_user_backup.sh"
  BACKUP_REPOSITORY=sftp:first
  RESTIC_PASSWORD='must-never-be-serialized'
  sha=0123456789abcdef0123456789abcdef01234567
  first="$(backup_daily_install_runtime "$sha")"
  [[ "$(backup_daily_install_runtime "$sha")" == "$first" ]]
  assert_fails grep -q 'must-never-be-serialized' "$first/runtime/backup-runtime.conf"
  BACKUP_REPOSITORY=sftp:second
  second="$(backup_daily_install_runtime "$sha")"
  [[ "$second" != "$first" ]]
  assert_fails backup_daily_existing_runtime_valid "$first" "$sha"
  backup_daily_existing_runtime_valid "$second" "$sha"
  grep -q 'second' "$second/runtime/backup-runtime.conf"
  printf 'tamper\n' >> "$second/bin/daily-user-backup"
  assert_fails backup_daily_existing_runtime_valid "$second" "$sha"
)

# A certificate must match all current identities and gate artifacts.
(
  STATE_ROOT="$tmp/cert"; mkdir -p "$STATE_ROOT/final"
  source "$ROOT/lib/validation_gates.sh"
  runtime_is_baremetal() { [[ "$runtime" == baremetal ]]; }
  validation_require_chain() { :; }
  workstation_runtime_fingerprint() { echo "$fingerprint"; }
  baseline_fingerprint() { echo hardware; }
  effective_config_sha256() { echo "$config"; }
  module_plan_sha256() { echo plan; }
  validation_imported_proof_path() { echo "$1"; }
  validation_file_sha256() { echo "hash-$1"; }
  runtime=baremetal; fingerprint=current; config=current; ENABLE_KVM=false
  cat > "$STATE_ROOT/final/certified.ok" <<'CERT'
verdict=PASS
validation_chain=PASS
driver_contract=PASS
application_runtime_contract=PASS
backup_runtime_contract=PASS
physical_runtime_contract=PASS
performance_contract=PASS
gaming_contract=PASS
gaming_profile=true
fingerprint=current
hardware_fingerprint=hardware
effective_config_sha256=current
module_plan_sha256=plan
gate1_proof_sha256=hash-1
gate2_proof_sha256=hash-2
CERT
  validation_final_certificate_valid
  config=changed; assert_fails validation_final_certificate_valid
  config=current; fingerprint=changed; assert_fails validation_final_certificate_valid
  fingerprint=current; runtime=vm; assert_fails validation_final_certificate_valid
)
# GNOME 50: Enabled: Yes does not imply State: ACTIVE.
(
  source "$ROOT/lib/common.sh"
  gnome-extensions() { printf '  Enabled: Yes\n  State: %s\n' "$extension_state"; }
  extension_state=ACTIVE; gnome_extension_active fixture
  for extension_state in INACTIVE ERROR 'OUT OF DATE' INITIALIZED UNKNOWN; do
    assert_fails gnome_extension_active fixture
  done
)
printf 'reliability regressions: PASS\n'
