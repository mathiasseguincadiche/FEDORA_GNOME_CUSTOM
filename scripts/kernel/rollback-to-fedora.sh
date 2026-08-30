#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run as a normal user; sudo is invoked when required.' >&2; exit 2; }
command -v dnf >/dev/null
command -v grubby >/dev/null || sudo dnf -y install grubby
printf 'This disables the Kernel Vanilla COPR and distro-syncs kernel/perf packages back to Fedora 44. Fedora fallback kernels are never deleted manually.\nType exactly ROLLBACK FEDORA KERNEL: '
read -r answer
[[ "$answer" == 'ROLLBACK FEDORA KERNEL' ]] || { echo 'Cancelled.'; exit 2; }
sudo dnf -y copr disable @kernel-vanilla/stable || true
mapfile -t names < <(rpm -qa --qf '%{NAME}\n' 'kernel*' 'libperf*' perf python3-perf rtla rv 2>/dev/null | sort -u)
sudo dnf -y --setopt=allow_vendor_change=1 distro-sync "${names[@]}"
echo 'Fedora packages converged. Keep all installed kernels until a successful Fedora-kernel reboot is verified.'
