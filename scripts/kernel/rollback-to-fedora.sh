#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run as a normal user; sudo is invoked when required.' >&2; exit 2; }
command -v dnf >/dev/null
command -v grubby >/dev/null || sudo dnf -y install grubby
printf 'This disables the Kernel Vanilla stable COPR and distro-syncs kernel/perf packages back to the selected Fedora release.\nInstalled kernels are never deleted manually; remove older versions later through DNF installonly retention.\nType exactly ROLLBACK FEDORA KERNEL: '
read -r answer
[[ "$answer" == 'ROLLBACK FEDORA KERNEL' ]] || { echo 'Cancelled.'; exit 2; }
sudo dnf -y copr disable @kernel-vanilla/stable || true
mapfile -t names < <(rpm -qa --qf '%{NAME}\n' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
sudo dnf -y --setopt=allow_vendor_change=1 distro-sync "${names[@]}"
fedora_latest="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v vanilla | sort -V | tail -n1 || true)"
if [[ -n "$fedora_latest" && -e "/boot/vmlinuz-$fedora_latest" ]]; then
  sudo grubby --set-default "/boot/vmlinuz-$fedora_latest"
  echo "GRUB default set to Fedora kernel $fedora_latest."
fi
echo 'Fedora packages converged. Keep all installed kernels until a successful Fedora-kernel reboot is verified.'
