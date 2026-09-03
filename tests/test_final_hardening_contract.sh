#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$(tr -d '[:space:]' < "$ROOT/VERSION")" == 0.14.0 ]]
grep -Fq '**Golden Workstation 0.14.0**' "$ROOT/README.md"

# User-decided HOST policy.
grep -Fq 'services --enabled=NetworkManager,firewalld --disabled=sshd' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'openssh-clients' "$ROOT/installer/generate-fedora44-kickstart.sh"
! grep -Eqi 'autopart[^\n]*--encrypted|luks' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$ROOT/config/kernel.conf"

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

grep -Fq 'REAL APPLY FAILED rc=' "$ROOT/install.sh"
grep -Fq 'SYSTEM MAY BE PARTIALLY CONVERGED' "$ROOT/install.sh"

# Arc B580 media probing is tied to PCI identity, never renderD128 ordering.
grep -Fq 'drm_render_node_for_pci_id 8086 e20b' "$ROOT/modules/gnome/22_multimedia_codecs.sh"
grep -Fq 'drm_render_node_for_pci_id 8086 e20b' "$ROOT/diagnostics/media-doctor"
grep -Fq 'VAAPI_DRM_DEVICE="auto"' "$ROOT/config/gnome.conf"

# Reviewed GNOME artifacts are content-pinned.
for installer in install-ding.sh install-show-desktop-plus.sh install-resource-monitor.sh; do
  grep -Fq 'sha256sum --check --status' "$ROOT/scripts/gnome/$installer"
done

# Backup retention remains explicit/manual and covers both snapshot classes.
grep -Fq 'BACKUP_PRUNE_AUTOMATICALLY="false"' "$ROOT/config/backup.conf"
grep -Fq 'fedora-gnome-custom-full fedora-gnome-custom-daily' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_APPLIED_SHA' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_APPLIED_SHA=' "$ROOT/modules/backup/60_daily_user_backup.sh"

# KVM protects all explicit non-default IPv4 routes while preserving Internet default route.
grep -Fq 'KVM_BLOCK_ROUTED_HOST_NETWORKS="true"' "$ROOT/config/virtualization.conf"
grep -Fq 'blocked_host_ipv4' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'protected_networks=' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'route show table main' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq '"$prefix" != default' "$ROOT/scripts/kvm/kvm_network_guard.sh"

# Community Flathub apps are explicit exceptions only.
grep -Fq 'UNVERIFIED_FLATHUB_ALLOWLIST=' "$ROOT/config/applications.conf"
grep -Fq 'professional_apps_validate_provenance' "$ROOT/modules/applications/41_professional_apps.sh"

# Privileged nftables service has a bounded systemd sandbox.
for token in NoNewPrivileges=yes ProtectSystem=strict ProtectHome=yes 'CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW'; do
  grep -Fq "$token" "$ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service"
done

echo 'final hardening contract: PASS'
