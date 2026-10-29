#!/usr/bin/env bash
# Gaming specification: the package sets, module order, canonical profile,
# certification wiring, forbidden tweaks and the Fedora 45 package pretest.
# Behaviour is exercised by test_gaming_behavior.sh and
# test_gaming_repositories_behavior.sh.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "gaming contract: FAIL: $*" >&2; exit 1; }

fedora_manifest=manifests/packages-gaming.txt
rpmfusion_manifest=manifests/packages-gaming-rpmfusion.txt
stack=modules/gaming/43_gaming_stack.sh
workflow=.github/workflows/fedora-gaming-pretest.yml

for pkg in gamemode gamescope mangohud goverlay steam-devices vulkan-tools mesa-vulkan-drivers.x86_64 mesa-vulkan-drivers.i686 mesa-dri-drivers.x86_64 mesa-dri-drivers.i686 vulkan-loader.x86_64 vulkan-loader.i686; do
  grep -Fxq "$pkg" "$fedora_manifest" || fail "$pkg missing from Fedora gaming manifest"
done
grep -Fxq steam "$rpmfusion_manifest" || fail 'Steam missing from RPM Fusion gaming manifest'

grep -Fq 'gaming.stack|GAMING|applications.validation|modules/gaming/43_gaming_stack.sh' manifests/module-plan.conf || fail 'gaming.stack missing from module plan'
grep -Fq 'gaming.validation|GAMING|gaming.stack|modules/gaming/44_gaming_validation.sh' manifests/module-plan.conf || fail 'gaming.validation missing from module plan'
grep -Fq 'kvm.preflight|KVM|applications.validation|modules/virtualization/30_kvm_preflight.sh' manifests/module-plan.conf || fail 'KVM must remain independent from gaming'
grep -Fxq 'GAMING_ENABLE="true"' config/gaming.conf || fail 'gaming canonical Golden profile must be enabled'

# The final certificate requires and records the canonical Gaming profile.
grep -Fq 'Canonical Golden profile requires Gaming enabled' diagnostics/final-certification || fail 'final Golden certification must reject Gaming disabled'
grep -Fq 'gaming-doctor" --quiet' diagnostics/final-certification || fail 'final Golden certification must execute gaming doctor'
grep -Fq 'gaming_contract=PASS' diagnostics/final-certification || fail 'final certificate must record gaming contract PASS'
grep -Fq 'gaming_profile=true' diagnostics/final-certification || fail 'final certificate must record canonical Gaming profile'

if grep -Eqi 'dnf[[:space:]]+copr|mesa-git|force_probe|sysctl[[:space:]]+-w|kernel.*(cachy|zen|liquorix)' "$stack"; then
  fail 'gaming module contains forbidden global/kernel/GPU tweaks'
fi
if grep -Eqi '(proton-ge|ge-proton|wine-staging)' "$stack" "$fedora_manifest" "$rpmfusion_manifest"; then
  fail 'custom Proton/Wine must not be imposed by the Golden profile'
fi

grep -Fq 'manifests/packages-gaming.txt' "$workflow" || fail 'gaming CI must consume Fedora gaming manifest'
grep -Fq 'manifests/packages-gaming-rpmfusion.txt' "$workflow" || fail 'gaming CI must consume Steam manifest'
grep -Fq 'fedora-workstation-repositories' "$workflow" || fail 'gaming CI must provision Fedora Steam repository definition'
grep -Fq 'gaming_steam_repository_file' "$workflow" || fail 'gaming CI must verify the actual Steam repository definition file'
grep -Fq 'fedora:45' "$workflow" || fail 'gaming CI must run against Fedora 45'
if grep -Eq '^[[:space:]]*steam([[:space:]]|$)' "$workflow"; then
  fail 'CI must not launch Steam in a headless container'
fi

echo 'gaming contract: PASS'
