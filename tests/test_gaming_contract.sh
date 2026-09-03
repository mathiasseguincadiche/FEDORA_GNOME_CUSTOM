#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "gaming contract: FAIL: $*" >&2; exit 1; }

fedora_manifest=manifests/packages-gaming.txt
rpmfusion_manifest=manifests/packages-gaming-rpmfusion.txt
stack=modules/gaming/43_gaming_stack.sh
validation=modules/gaming/44_gaming_validation.sh
doctor=diagnostics/gaming-doctor
workflow=.github/workflows/fedora-gaming-pretest.yml

for file in "$fedora_manifest" "$rpmfusion_manifest" "$stack" "$validation" "$doctor" "$workflow"; do
  [[ -s "$file" ]] || fail "missing $file"
done

for pkg in gamemode gamescope mangohud goverlay steam-devices vulkan-tools mesa-vulkan-drivers.x86_64 mesa-vulkan-drivers.i686 mesa-dri-drivers.x86_64 mesa-dri-drivers.i686 vulkan-loader.x86_64 vulkan-loader.i686; do
  grep -Fxq "$pkg" "$fedora_manifest" || fail "$pkg missing from Fedora gaming manifest"
done
grep -Fxq steam "$rpmfusion_manifest" || fail 'Steam missing from RPM Fusion gaming manifest'

grep -Fq 'gaming.stack|GAMING|applications.validation|modules/gaming/43_gaming_stack.sh' manifests/module-plan.conf || fail 'gaming.stack missing from module plan'
grep -Fq 'gaming.validation|GAMING|gaming.stack|modules/gaming/44_gaming_validation.sh' manifests/module-plan.conf || fail 'gaming.validation missing from module plan'
grep -Fq 'kvm.preflight|KVM|applications.validation|modules/virtualization/30_kvm_preflight.sh' manifests/module-plan.conf || fail 'KVM must remain independent from gaming'

grep -Fq 'GAMING_ENABLE:-false' "$stack" || fail 'gaming must default disabled'
grep -Fq -- '--enablerepo=rpmfusion-nonfree-steam' "$stack" || fail 'Steam install must use the dedicated RPM Fusion repo transactionally'
grep -Fq 'Proton remains Steam-managed' "$stack" || fail 'Steam-managed Proton policy missing'

if grep -Eqi 'dnf[[:space:]]+copr|mesa-git|force_probe|sysctl[[:space:]]+-w|kernel.*(cachy|zen|liquorix)' "$stack"; then
  fail 'gaming module contains forbidden global/kernel/GPU tweaks'
fi
if grep -Eqi '(proton-ge|ge-proton|wine-staging)' "$stack" "$fedora_manifest" "$rpmfusion_manifest"; then
  fail 'custom Proton/Wine must not be imposed by the Golden profile'
fi

grep -Fq 'runtime_is_baremetal' "$doctor" || fail 'gaming doctor must separate bare-metal validation'
grep -Fq 'graphics-doctor' "$doctor" || fail 'Arc graphics doctor integration missing'
grep -Fq 'display-doctor' "$doctor" || fail '1440p/240 Hz display doctor integration missing'
grep -Fq 'vulkaninfo --summary' "$doctor" || fail 'bare-metal Vulkan renderer probe missing'
grep -Fq 'Steam-managed Proton' "$doctor" || fail 'Proton diagnostic policy missing'

grep -Fq 'manifests/packages-gaming.txt' "$workflow" || fail 'gaming CI must consume Fedora gaming manifest'
grep -Fq 'manifests/packages-gaming-rpmfusion.txt' "$workflow" || fail 'gaming CI must consume Steam manifest'
grep -Fq 'fedora:44' "$workflow" || fail 'gaming CI must run against Fedora 44'
! grep -Eq '(^|[[:space:]])steam[[:space:]]+--version|steam[[:space:]]*$' "$workflow" || fail 'CI must not launch Steam in a headless container'

echo 'gaming contract: PASS'
