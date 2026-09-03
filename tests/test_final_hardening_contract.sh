#!/usr/bin/env bash
# Test harnesses below intentionally isolate mock environment mutations in
# subshells and define functions invoked indirectly by sourced orchestrator code.
# shellcheck disable=SC2030,SC2031,SC2317
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$(tr -d '[:space:]' < "$ROOT/VERSION")" == 0.14.0 ]]
grep -Fq '**Golden Workstation 0.14.0**' "$ROOT/README.md"
grep -Fq '## 0.14.0 — 2026-09-03' "$ROOT/CHANGELOG.md"

# User-decided HOST policy.
grep -Fq 'services --enabled=NetworkManager,firewalld --disabled=sshd' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'openssh-clients' "$ROOT/installer/generate-fedora44-kickstart.sh"
if grep -Eqi 'autopart[^\n]*--encrypted|luks' "$ROOT/installer/generate-fedora44-kickstart.sh"; then
  echo 'Kickstart must not silently introduce LUKS into the chosen Golden policy' >&2
  exit 1
fi
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_BLOCK_SECURE_BOOT="true"' "$ROOT/config/kernel.conf"

# Config files are declarative assignments only: no source-time command execution.
python3 - "$ROOT/config" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
assignment = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=.*$')
for path in sorted(root.glob('*.conf')):
    for lineno, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if not assignment.match(line):
            raise SystemExit(f'{path}:{lineno}: non-declarative config line: {raw}')
        for forbidden in ('$(', '`', '<(', '>(', '&&', '||', ';'):
            if forbidden in line:
                raise SystemExit(f'{path}:{lineno}: executable shell syntax forbidden in config: {forbidden}')
PY

# Mutating commands must not execute at module source time. Project modules keep
# lifecycle mutations indented inside functions; an unindented mutator is a regression.
python3 - "$ROOT/modules" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
mutator = re.compile(r'^(?:sudo|dnf|flatpak|systemctl|nft|virsh|run_mutating|rm|cp|mv|install)\b')
for path in sorted(root.rglob('*.sh')):
    for lineno, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not raw or raw[0].isspace() or raw.startswith('#'):
            continue
        if mutator.match(raw):
            raise SystemExit(f'{path}:{lineno}: possible source-time mutation: {raw}')
PY

# Ambiguous runtime must never be promoted to bare metal.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/systemd-detect-virt" <<'SH'
#!/usr/bin/env sh
case "${1:-}" in
  --container|--vm) exit 1 ;;
  --quiet) exit 2 ;;
esac
exit 2
SH
chmod +x "$tmp/systemd-detect-virt"
(
  PATH="$tmp:$PATH"
  CI=false GITHUB_ACTIONS=false GITLAB_CI=false
  source "$ROOT/lib/common.sh"
  runtime_virtualization_detect() { return 1; }
  [[ "$(runtime_environment_detect)" == unknown ]]
  ! runtime_is_baremetal
)

# A catalog module missing its apply function must fail rather than becoming OK.
cat > "$tmp/fake.sh" <<'SH'
fake_module_precheck() { :; }
fake_module_plan() { :; }
fake_module_postcheck() { :; }
SH
(
  REPO_ROOT="$tmp"
  MODULE_LOG="$tmp/module.log"
  EXIT_CONFIG_FAILED=12
  declare -A CATALOG_PATH=( [fake.module]='fake.sh' )
  declare -A CATALOG_SCOPE=( [fake.module]='TEST' )
  ui_check() { :; }
  is_true() { [[ "${1,,}" == true ]]; }
  repo_commit() { printf unknown; }
  source "$ROOT/lib/orchestrator.sh"
  if orchestrator_run_module fake.module; then
    echo 'missing module apply function was accepted' >&2
    exit 1
  fi
  [[ "${ORCH_RESULTS[*]}" == *'contract missing fake_module_apply'* ]]
)

# A mid-APPLY module failure preserves its rc and produces a durable partial report.
cat > "$tmp/fail.sh" <<'SH'
fail_module_precheck() { :; }
fail_module_plan() { printf 'plan\n'; }
fail_module_apply() { return 42; }
fail_module_postcheck() { :; }
SH
(
  REPO_ROOT="$tmp"
  MODULE_LOG="$tmp/module-failure.log"
  REPORT_ROOT="$tmp/reports"
  RUN_ID='hardening-test'
  DRY_RUN=false
  mkdir -p "$REPORT_ROOT"
  declare -a CATALOG_IDS=(fail.module)
  declare -A CATALOG_PATH=( [fail.module]='fail.sh' )
  declare -A CATALOG_SCOPE=( [fail.module]='TEST' )
  ui_check() { :; }
  is_true() { [[ "${1,,}" == true ]]; }
  repo_commit() { printf test-commit; }
  source "$ROOT/lib/orchestrator.sh"
  rc=0
  orchestrator_run_all || rc=$?
  [[ "$rc" -eq 42 ]]
  report="$(orchestrator_report)"
  [[ -s "$report" ]]
  grep -Eq 'fail\.module.*apply rc=42' "$report"
)
grep -Fq 'REAL APPLY FAILED rc=' "$ROOT/install.sh"
grep -Fq 'SYSTEM MAY BE PARTIALLY CONVERGED' "$ROOT/install.sh"

# Arc B580 media probing is tied to PCI identity, never render-node ordering.
grep -Fq 'drm_render_node_for_pci_id 8086 e20b' "$ROOT/modules/gnome/22_multimedia_codecs.sh"
grep -Fq 'drm_render_node_for_pci_id 8086 e20b' "$ROOT/diagnostics/media-doctor"
grep -Fq 'VAAPI_DRM_DEVICE="auto"' "$ROOT/config/gnome.conf"
mkdir -p "$tmp/drm/renderD128/device" "$tmp/drm/renderD129/device"
printf '0x1002\n' > "$tmp/drm/renderD128/device/vendor"
printf '0x164e\n' > "$tmp/drm/renderD128/device/device"
printf '0x8086\n' > "$tmp/drm/renderD129/device/vendor"
printf '0xe20b\n' > "$tmp/drm/renderD129/device/device"
(
  source "$ROOT/lib/common.sh"
  DRM_SYSFS_ROOT="$tmp/drm"
  [[ "$(drm_render_node_for_pci_id 8086 e20b)" == /dev/dri/renderD129 ]]
)

# Reviewed GNOME artifacts are content-pinned.
for installer in install-ding.sh install-show-desktop-plus.sh install-resource-monitor.sh; do
  grep -Fq 'sha256sum --check --status' "$ROOT/scripts/gnome/$installer"
done
grep -Fq '48175f0b5c1f8a1a724d761198c91d6994e91e28aec685605ae6a240b0a95aae' "$ROOT/docs/SUPPLY_CHAIN.md"
grep -Fq '9ceab00be63b93c4eade16cf804bf4edd587632750aa89b78e317673fd6016a9' "$ROOT/docs/SUPPLY_CHAIN.md"
grep -Fq '18f49cf20bd8f96f22f6048d7404e51cb414c1aea94ca16d0c2ad3634e9d8bf2' "$ROOT/docs/SUPPLY_CHAIN.md"

# Backup retention remains explicit/manual and covers both snapshot classes.
grep -Fq 'BACKUP_PRUNE_AUTOMATICALLY="false"' "$ROOT/config/backup.conf"
grep -Fq 'fedora-gnome-custom-full fedora-gnome-custom-daily' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_APPLIED_SHA' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_APPLIED_SHA=' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq "cc_option 9 'Appliquer rétention Restic'" "$ROOT/lib/control_center.sh"
grep -Fq "prune) \"\$REPO_ROOT/scripts/backup/backup-now.sh\" --prune" "$ROOT/lib/control_center.sh"
grep -Fq 'copie de récupération hors machine' "$ROOT/docs/BACKUP_RESTORE.md"
grep -Fq 'SHA appliqué' "$ROOT/docs/BACKUP_RESTORE.md"

# KVM protects explicit non-default IPv4 HOST routes while preserving Internet default route.
grep -Fq 'KVM_BLOCK_ROUTED_HOST_NETWORKS="true"' "$ROOT/config/virtualization.conf"
grep -Fq 'blocked_host_ipv4' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'protected_networks=' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'route show table main' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq "\"\$prefix\" != default" "$ROOT/scripts/kvm/kvm_network_guard.sh"
cat > "$tmp/ip" <<'SH'
#!/usr/bin/env sh
case "$*" in
  '-4 route show default')
    echo 'default via 192.168.1.1 dev enp1s0 proto dhcp'
    ;;
  '-4 route show table main')
    cat <<'EOF'
default via 192.168.1.1 dev enp1s0 proto dhcp
192.168.1.0/24 dev enp1s0 proto kernel scope link src 192.168.1.20
10.8.0.0/24 dev tun0 proto kernel scope link src 10.8.0.2
172.20.0.0/16 via 10.8.0.1 dev tun0
192.168.50.0/24 dev virbr50 proto kernel scope link src 192.168.50.254
EOF
    ;;
esac
SH
cat > "$tmp/nft" <<'SH'
#!/usr/bin/env sh
if [ "${1:-}" = list ]; then
  echo 'comment "fedora-gnome-custom normal block VM to protected host networks"'
fi
exit 0
SH
chmod +x "$tmp/ip" "$tmp/nft"
(
  PATH="$tmp:$PATH"
  output="$(KVM_BLOCK_ROUTED_HOST_NETWORKS=true bash "$ROOT/scripts/kvm/kvm_network_guard.sh" check)"
  grep -Fq 'protected_networks=10.8.0.0/24,172.20.0.0/16,192.168.1.0/24' <<<"$output"
  grep -Fq 'guard_mode=normal' <<<"$output"
)
grep -Fq 'protected_networks' "$ROOT/scripts/kvm/runtime_certification.sh"
grep -Fq 'block VM to protected host networks' "$ROOT/diagnostics/virtualization-doctor"

# Community Flathub apps are explicit exceptions only.
grep -Fq 'UNVERIFIED_FLATHUB_ALLOWLIST=' "$ROOT/config/applications.conf"
grep -Fq 'professional_apps_validate_provenance' "$ROOT/modules/applications/41_professional_apps.sh"
grep -Fq 'Exceptions Flathub communautaires' "$ROOT/docs/SUPPLY_CHAIN.md"

# Privileged nftables service has a bounded systemd sandbox.
for token in NoNewPrivileges=yes ProtectSystem=strict ProtectHome=yes 'CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW'; do
  grep -Fq "$token" "$ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service"
done

# Governance/release files are present; live main protection is checked separately by check-main-protection.sh.
[[ -r "$ROOT/SECURITY.md" ]]
[[ -r "$ROOT/.github/CODEOWNERS" ]]
[[ -r "$ROOT/.github/pull_request_template.md" ]]
[[ -x "$ROOT/scripts/development/check-main-protection.sh" || -r "$ROOT/scripts/development/check-main-protection.sh" ]]

echo 'final hardening contract: PASS'
