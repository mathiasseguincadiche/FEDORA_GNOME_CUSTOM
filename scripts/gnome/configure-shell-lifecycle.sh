#!/usr/bin/env bash
# User service policy shared by Fedora 45 installation and the disposable lab.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[[ "${HOST_RELEASE:-45}" == 45 ]] || { echo 'Shell lifecycle policy requires Fedora 45' >&2; exit 1; }
relative=systemd/user/org.gnome.Shell@user.service.d/50-fgc-child-lifecycle.conf
source_file="$ROOT/$relative"
target="${XDG_CONFIG_HOME:-$HOME/.config}/$relative"

case "${1:-}" in
  apply)
    install -D -m 0644 "$source_file" "$target"
    systemctl --user daemon-reload
    ;;
  verify) ;;
  *) echo 'Usage: configure-shell-lifecycle.sh apply|verify' >&2; exit 2 ;;
esac
cmp -s "$source_file" "$target" || { echo 'GNOME Shell lifecycle drop-in missing or modified' >&2; exit 1; }
actual="$(systemctl --user show org.gnome.Shell@user.service --property=KillMode --value)"
[[ "$actual" == mixed ]] || { echo "GNOME Shell lifecycle policy ineffective: KillMode=$actual" >&2; exit 1; }
echo 'GNOME Shell lifecycle: KillMode=mixed; child cleanup remains enforced'
