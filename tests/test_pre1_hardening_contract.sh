#!/usr/bin/env bash
# Pre-1.0 hardening specification: version format, retired configuration keys,
# the KVM network policy values and application provenance. Behaviour is
# exercised by test_pre1_hardening_behavior.sh (runtime identity, diagnostic
# routing, certification fingerprint, KVM IPv6, preflight) and by the kernel,
# Golden workstation and desktop lifecycle behaviour tests.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "pre-1.0 hardening contract: FAIL: $*" >&2; exit 1; }

version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail "VERSION is not semver: $version"

for stale in BASELINE_NVME_TEST_SECONDS BASELINE_NVME_VERIFY_SECONDS DISPLAY_PRESERVE_VRR FINAL_CERT_REQUIRE_DISPLAY_REPAIR FINAL_CERT_REQUIRE_NAUTILUS_COLDSTART FINAL_CERT_REQUIRE_KERNEL ALLOW_EXPERIMENTAL_KERNEL_ARGS CHECK_VULKAN CHECK_VAAPI CHECK_DRM_ERRORS CHECK_GPU_RESETS CHECK_DISPLAY_MODE CHECK_VRR CHECK_HDR; do
  if grep -RIn "^${stale}=" "$ROOT/config" >/dev/null; then fail "stale config key remains: $stale"; fi
done

(
  set +u
  source "$ROOT/config/virtualization.conf"
  [[ "$KVM_IPV6_ENABLED" == false && "$KVM_BLOCK_ROUTED_HOST_NETWORKS" == true ]]
) || fail 'KVM must stay IPv4-only and block routed host networks'
grep -Fq 'performance_contract=PASS' "$ROOT/diagnostics/final-certification" || fail 'certificate does not record the performance contract'
if grep -Fq 'git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git' "$ROOT/installer/lib/generate-kickstart.sh"; then
  fail 'Kickstart must fetch and checkout the audited SHA instead of cloning mutable main'
fi

[[ -r "$ROOT/manifests/application-provenance.tsv" ]] || fail 'application provenance manifest missing'
while IFS= read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  grep -Fq "$app" "$ROOT/manifests/application-provenance.tsv" || fail "missing provenance: $app"
done < "$ROOT/manifests/flatpaks-applications-professional.txt"

echo 'pre-1.0 hardening contract: PASS'
