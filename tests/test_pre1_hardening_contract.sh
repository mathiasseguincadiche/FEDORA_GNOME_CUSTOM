#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$(<"$ROOT/VERSION")" == '0.12.0' ]]
grep -Fq '**Golden Workstation 0.12.0**' "$ROOT/README.md"
grep -Fq '## 0.12.0 — 2026-09-01' "$ROOT/CHANGELOG.md"

# Runtime identity must fail closed for virtualized environments.
grep -Fq 'systemd-detect-virt --container' "$ROOT/lib/common.sh"
grep -Fq 'systemd-detect-virt --vm' "$ROOT/lib/common.sh"
grep -Fq 'vm|container)' "$ROOT/diagnostic.sh"

# The final certificate is tied to graphics/runtime versions and includes KVM host health.
grep -Fq 'FINAL_CERT_FINGERPRINT_PACKAGES=' "$ROOT/config/performance.conf"
grep -Fq 'workstation_runtime_fingerprint' "$ROOT/lib/baseline.sh"
grep -Fq 'workstation_runtime_fingerprint' "$ROOT/diagnostics/final-certification"
grep -Fq 'diagnostics/virtualization-doctor' "$ROOT/diagnostics/final-certification"

for stale in BASELINE_NVME_TEST_SECONDS BASELINE_NVME_VERIFY_SECONDS DISPLAY_PRESERVE_VRR FINAL_CERT_REQUIRE_DISPLAY_REPAIR FINAL_CERT_REQUIRE_NAUTILUS_COLDSTART FINAL_CERT_REQUIRE_KERNEL ALLOW_EXPERIMENTAL_KERNEL_ARGS CHECK_VULKAN CHECK_VAAPI CHECK_DRM_ERRORS CHECK_GPU_RESETS CHECK_DISPLAY_MODE CHECK_VRR CHECK_HDR; do
  ! grep -RIn "^${stale}=" "$ROOT/config" >/dev/null || { echo "stale config key remains: $stale" >&2; exit 1; }
done

grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'kernel_latest_available' "$ROOT/modules/system/01a_kernel_latest_stable.sh"
grep -Fq 'KERNEL_VENDOR_CHANGE_ALLOWED' "$ROOT/modules/system/01a_kernel_latest_stable.sh"
grep -Fq 'DISPLAY_CERT_TOLERANCE_HZ' "$ROOT/diagnostics/display-doctor"

grep -Fq "repo_sha=\"\$(git -C \"\$REPO_ROOT\" rev-parse HEAD" "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq "fetch --depth 1 origin \${repo_sha}" "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'checkout --detach FETCH_HEAD' "$ROOT/installer/generate-fedora44-kickstart.sh"
if grep -Fq 'git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git' "$ROOT/installer/generate-fedora44-kickstart.sh"; then
  echo 'Kickstart must fetch and checkout the audited SHA instead of cloning mutable main' >&2
  exit 1
fi

grep -Fq 'KVM_IPV6_ENABLED="false"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM IPv6 is fail-closed' "$ROOT/modules/virtualization/34_kvm_network.sh"
grep -Fq 'LIFECYCLE_FLATPAK_UPDATE_POLICY="manual"' "$ROOT/config/desktop.conf"
grep -Fq 'unexpected project-owned unattended Flatpak updater exists' "$ROOT/diagnostics/lifecycle-doctor"
grep -Fq 'NON-MUTATING PREFLIGHT / CONVERGENCE PLAN' "$ROOT/install.sh"
grep -Fq 'PREFLIGHT SKIP MUTATION' "$ROOT/lib/mutations.sh"

[[ -r "$ROOT/manifests/application-provenance.tsv" ]]
while IFS= read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  grep -Fq "$app" "$ROOT/manifests/application-provenance.tsv" || { echo "missing provenance: $app" >&2; exit 1; }
done < "$ROOT/manifests/flatpaks-applications-professional.txt"

echo 'pre-1.0 hardening contract: PASS'
