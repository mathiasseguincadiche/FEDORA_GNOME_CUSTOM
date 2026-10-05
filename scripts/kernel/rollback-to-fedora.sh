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
kernel_lifecycle_require_host_gate
fedora_require_selected
command -v dnf5 >/dev/null
command -v grubby >/dev/null || sudo dnf5 -y install grubby
printf 'Recovery to Fedora %s RPMs. Upstream repositories will be disabled; installed kernels remain until a successful reboot.\nType exactly ROLLBACK FEDORA KERNEL: ' "${HOST_RELEASE:-44}"
read -r answer
[[ "$answer" == 'ROLLBACK FEDORA KERNEL' ]] || { echo 'Cancelled.'; exit 2; }
for copr in @kernel-vanilla/stable @kernel-vanilla/fedora; do
  sudo dnf5 -y copr disable "$copr" || { echo "Cannot disable $copr; refusing recovery." >&2; exit 40; }
done
sudo python3 "$REPO_ROOT/scripts/kernel/pin-upstream-target.py" --clear
mapfile -t names < <(rpm -qa --qf '%{NAME}\n' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
(( ${#names[@]} > 0 ))
# Restrict RPM provenance even if unrelated third-party repositories are enabled.
sudo dnf5 -y --repo=fedora --repo=updates --setopt=allow_vendor_change=1 distro-sync "${names[@]}"
fedora_latest="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core \
  | grep -E "^[0-9]+[.][0-9]+([.][0-9]+)?-[0-9.]+[.]fc${HOST_RELEASE:-44}[.]x86_64$" | sort -V | tail -n1)"
[[ -n "$fedora_latest" && -e "/boot/vmlinuz-$fedora_latest" ]]
sudo grubby --set-default "/boot/vmlinuz-$fedora_latest"
[[ "$(kernel_lifecycle_default_release)" == "$fedora_latest" ]]
echo "Fedora kernel $fedora_latest selected. Reboot, validate recovery and requalify the retained runtime."
