#!/usr/bin/env bash
# Stable Fedora repositories in production; testing is an explicit QEMU-only candidate input.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="$root/scripts/gnome/fedora45-rpm-extensions.py"
specs="$(python3 "$helper" --specs)"
mapfile -t packages <<<"$specs"
repos=(--disablerepo='*' --enablerepo=fedora --enablerepo=updates)
case "${1:-}" in
  --stable-check)
    # No installation: promotion must prove the pinned RPMs are available
    # without updates-testing. An empty repoquery is never a successful proof.
    available="$(dnf5 --releasever=45 "${repos[@]}" --refresh repoquery --qf '%{name}-%{version}-%{release}\n' "${packages[@]}")"
    for package in "${packages[@]}"; do grep -Fxq "$package" <<<"$available"; done
    exit 0 ;;
  --lab-testing)
    [[ "$root" == /opt/fgc-lab/repo && "$(hostname)" == fgc-fedora-ci && -e /etc/fgc-ci-lab ]] || exit 50
    case "$(systemd-detect-virt)" in kvm|qemu) ;; *) exit 50;; esac
    repos+=(--enablerepo=updates-testing)
    ;;
  '') python3 "$root/scripts/development/fedora-profile.py" validate "$root" 45 ;;
  *) exit 2 ;;
esac
[[ "$EUID" == 0 ]] || { echo 'RPM installation requires root.' >&2; exit 50; }
grep -Eq '^VERSION_ID="?45"?$' /etc/os-release || exit 50
dnf5 "${repos[@]}" --setopt=gpgcheck=1 -y install "${packages[@]}"
python3 "$helper" --verify
