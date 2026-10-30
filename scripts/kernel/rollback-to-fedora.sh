#!/usr/bin/env bash
# Explicit recovery; only the selected distribution's Fedora repositories supply RPMs.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run as a normal user; sudo is invoked when required.' >&2; exit 2; }
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/install_lock.sh"
install_lock_acquire || exit $?
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"
fail() { echo "Fedora kernel recovery: $1" >&2; exit "${2:-40}"; }
kernel_lifecycle_require_host_gate || exit $?
fedora_require_selected || fail "the running system is not the selected Fedora ${HOST_RELEASE:-45} release" 20
command -v dnf5 >/dev/null || fail 'dnf5 is required' 20
command -v grubby >/dev/null || sudo dnf5 -y install grubby || fail 'grubby is required and could not be installed' 20
printf 'Recovery to Fedora %s RPMs. Upstream repositories will be disabled; installed kernels remain until a successful reboot.
Type exactly ROLLBACK FEDORA KERNEL: ' "${HOST_RELEASE:-45}"
read -r answer
[[ "$answer" == 'ROLLBACK FEDORA KERNEL' ]] || { echo 'Cancelled.'; exit 2; }
for copr in @kernel-vanilla/stable @kernel-vanilla/fedora; do
  sudo dnf5 -y copr disable "$copr" || fail "cannot disable $copr; refusing recovery."
done
sudo python3 "$REPO_ROOT/scripts/kernel/pin-upstream-target.py" --clear || fail 'cannot clear the upstream kernel versionlock'
mapfile -t names < <(rpm -qa --qf '%{NAME}
' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
(( ${#names[@]} > 0 )) || fail 'no installed kernel package found'
# Restrict RPM provenance even if unrelated third-party repositories are enabled.
sudo dnf5 -y --repo=fedora --repo=updates --setopt=allow_vendor_change=1 distro-sync "${names[@]}"   || fail 'distro-sync from the Fedora repositories failed; the current GRUB default is unchanged'
fedora_latest="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}
' kernel-core 2>/dev/null   | grep -E "^[0-9]+[.][0-9]+([.][0-9]+)?-[0-9.]+[.]fc${HOST_RELEASE:-45}[.]x86_64$" | sort -V | tail -n1 || true)"
[[ -n "$fedora_latest" ]] || fail "no Fedora ${HOST_RELEASE:-45} kernel-core is installed after distro-sync; the current GRUB default is unchanged"
[[ -e "$(kernel_lifecycle_boot_image "$fedora_latest")" ]] || fail "boot image missing for $fedora_latest; the current GRUB default is unchanged"
sudo grubby --set-default "$(kernel_lifecycle_boot_image "$fedora_latest")" || fail "grubby could not select $fedora_latest"
[[ "$(kernel_lifecycle_default_release)" == "$fedora_latest" ]] || fail "GRUB default is $(kernel_lifecycle_default_release), not $fedora_latest"
echo "Fedora kernel $fedora_latest selected. Reboot, validate recovery and requalify the retained runtime."
