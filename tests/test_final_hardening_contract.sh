#!/usr/bin/env bash
# Cross-cutting hardening: declarative config, no source-time mutation, and
# behaviour runs of runtime detection, the orchestrator, B580 render-node
# selection and the KVM host-network guard. Domain rules live in their own
# tests (kernel, backup, Kickstart render, extensions, Control Center).
# Test harnesses below isolate mock environment mutations in subshells and
# define functions invoked indirectly by sourced orchestrator code.
# shellcheck disable=SC2030,SC2031,SC2317
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]
grep -Fq "## $version —" "$ROOT/CHANGELOG.md"

# Config is schema-validated before sourcing and remains declarative.
bash "$ROOT/scripts/config/validate-config.sh" "$ROOT/config" >/dev/null
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

# Mutating commands must not execute at module source time.
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

cp -a "$ROOT/lib" "$ROOT/config" "$tmp/"
mkdir -p "$tmp/scripts"
cp -a "$ROOT/scripts/config" "$tmp/scripts/"

# A catalog module missing its apply function must fail rather than becoming OK.
cat > "$tmp/fake.sh" <<'SH'
fake_module_precheck() { :; }
fake_module_plan() { :; }
fake_module_postcheck() { :; }
SH
(
  REPO_ROOT="$tmp"
  MODULE_LOG="$tmp/module.log"
  declare -A CATALOG_PATH=( [fake.module]='fake.sh' )
  declare -A CATALOG_SCOPE=( [fake.module]='TEST' )
  source "$ROOT/lib/orchestrator.sh"
  if orchestrator_run_module fake.module; then
    echo 'missing module apply function was accepted' >&2
    exit 1
  fi
  [[ "${ORCH_RESULTS[*]}" == *'contract missing fake_module_apply'* ]]
)

# A mid-APPLY module failure preserves its rc and produces durable text + JSON reports.
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
  is_true() { [[ "${1,,}" == true ]]; }
  repo_commit() { printf test-commit; }
  source "$ROOT/lib/orchestrator.sh"
  rc=0
  orchestrator_run_all || rc=$?
  [[ "$rc" -eq 42 ]]
  report="$(orchestrator_report)"
  [[ -s "$report" ]]
  [[ -s "$REPORT_ROOT/run-$RUN_ID.json" ]]
  grep -Eq 'fail\.module.*apply.*42.*apply rc=42' "$report"
)

# Arc B580 media probing is tied to PCI identity, never render-node ordering.
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

# KVM protects explicit main-table and policy-routed IPv4 HOST networks while preserving the Internet default route.
grep -Fxq 'KVM_BLOCK_ROUTED_HOST_NETWORKS="true"' "$ROOT/config/virtualization.conf"
cat > "$tmp/ip" <<'SH'
#!/usr/bin/env sh
case "$*" in
  '-4 route show default')
    echo 'default via 192.168.1.1 dev enp1s0 proto dhcp'
    ;;
  '-4 rule show')
    cat <<'EOF'
0: from all lookup local
1000: from 10.8.0.0/24 lookup 100
32766: from all lookup main
32767: from all lookup default
EOF
    ;;
  '-4 route show table main')
    cat <<'EOF'
default via 192.168.1.1 dev enp1s0 proto dhcp
192.168.1.0/24 dev enp1s0 proto kernel scope link src 192.168.1.20
192.168.50.0/24 dev virbr50 proto kernel scope link src 192.168.50.254
EOF
    ;;
  '-4 route show table 100')
    cat <<'EOF'
10.8.0.0/24 dev tun0 proto kernel scope link src 10.8.0.2
172.20.0.0/16 via 10.8.0.1 dev tun0
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
  grep -Fq 'policy_tables=100' <<<"$output"
  grep -Fq 'protected_networks=10.8.0.0/24,172.20.0.0/16,192.168.1.0/24' <<<"$output"
  grep -Fq 'guard_mode=normal' <<<"$output"
)
# Community Flathub apps are explicit exceptions only.
grep -Fq 'UNVERIFIED_FLATHUB_ALLOWLIST=' "$ROOT/config/applications.conf"

# Privileged nftables service has a bounded systemd sandbox.
for token in NoNewPrivileges=yes ProtectSystem=strict ProtectHome=yes 'CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW'; do
  grep -Fq "$token" "$ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service"
done

# Governance/release artifacts are versioned; live repository settings are checked separately.
[[ -r "$ROOT/SECURITY.md" ]]
[[ -r "$ROOT/.github/CODEOWNERS" ]]
[[ -r "$ROOT/.github/pull_request_template.md" ]]
[[ -r "$ROOT/.github/release-manifest.env" ]]
[[ -r "$ROOT/.github/workflows/release.yml" ]]
# The hardening contract validates the prerelease shape instead of pinning one RC forever.
version_regex="${version//./\\.}"
grep -Eq "^RELEASE_TAG=v${version_regex}-rc[.][0-9]+$" "$ROOT/.github/release-manifest.env"
grep -Fxq 'RELEASE_PRERELEASE=true' "$ROOT/.github/release-manifest.env"
[[ -x "$ROOT/scripts/development/check-main-protection.sh" || -r "$ROOT/scripts/development/check-main-protection.sh" ]]

echo 'final hardening contract: PASS'
