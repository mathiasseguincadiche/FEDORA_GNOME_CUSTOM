#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="$(<"$ROOT/VERSION")"
[[ "$(printf '%s\n%s\n' '0.9.0' "$version" | sort -V | head -n1)" == "0.9.0" ]]

grep -Fq 'ENABLE_APPINDICATOR="true"' "$ROOT/config/gnome.conf"
grep -Fq 'APPINDICATOR_UUID="appindicatorsupport@rgcjonas.gmail.com"' "$ROOT/config/gnome.conf"
grep -Fxq 'gnome-shell-extension-appindicator' "$ROOT/manifests/packages-gnome-extensions.txt"
grep -Fq 'gnome_extension_enable_checked AppIndicator' "$ROOT/modules/gnome/24_gnome_extensions.sh"

for pkg in gnome-keyring gnome-keyring-pam libsecret cups ipp-usb avahi sane-airscan NetworkManager-openvpn NetworkManager-openconnect tuned-ppd glibc-langpack-fr hunspell-fr liberation-fonts-all remmina libimobiledevice intel-compute-runtime intel-level-zero intel-opencl clinfo dnf5-plugin-automatic; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-desktop-integration.txt"
done

grep -Fq 'desktop.integration|DESKTOP|gnome.validation|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'desktop.lifecycle|DESKTOP|desktop.integration|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'backup.daily|BACKUP|backup.validation|' "$ROOT/manifests/module-plan.conf"

for doctor in desktop-integration-doctor portal-doctor arc-compute-doctor lifecycle-doctor daily-backup-doctor; do
  grep -Fq "$doctor" "$ROOT/diagnostics/final-certification"
done

grep -Fq 'LIFECYCLE_AUTOMATIC_DOWNLOADS="true"' "$ROOT/config/desktop.conf"
grep -Fq 'LIFECYCLE_AUTOMATIC_INSTALLS="false"' "$ROOT/config/desktop.conf"
grep -Fq 'LIFECYCLE_AUTOMATIC_REBOOT="never"' "$ROOT/config/desktop.conf"
grep -Fq 'LIFECYCLE_FLATPAK_UPDATE_POLICY="manual"' "$ROOT/config/desktop.conf"
grep -Fq "download_updates = \${LIFECYCLE_AUTOMATIC_DOWNLOADS:-true}" "$ROOT/modules/desktop/27_lifecycle.sh"
grep -Fq "apply_updates = \${LIFECYCLE_AUTOMATIC_INSTALLS:-false}" "$ROOT/modules/desktop/27_lifecycle.sh"
grep -Fq "reboot = \${LIFECYCLE_AUTOMATIC_REBOOT:-never}" "$ROOT/modules/desktop/27_lifecycle.sh"
if grep -Fq 'apply_updates = true' "$ROOT/modules/desktop/27_lifecycle.sh"; then
  echo 'unattended package installation must remain disabled' >&2
  exit 1
fi
grep -Fq 'dnf5-automatic.timer' "$ROOT/modules/desktop/27_lifecycle.sh"
grep -Fq 'fstrim.timer' "$ROOT/modules/desktop/27_lifecycle.sh"
grep -Fq 'unexpected project-owned unattended Flatpak updater exists' "$ROOT/diagnostics/lifecycle-doctor"

grep -Fq 'DAILY_BACKUP_ENABLED="true"' "$ROOT/config/backup.conf"
grep -Fq 'fedora-gnome-daily-backup.timer' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'OnCalendar=daily' "$ROOT/systemd/user/fedora-gnome-daily-backup.timer"
grep -Fq 'fedora-gnome-custom/secrets' "$ROOT/scripts/backup/daily-user-backup.sh"
if grep -Fq -- '--prune' "$ROOT/scripts/backup/daily-user-backup.sh"; then
  echo 'daily backup must not prune snapshots automatically' >&2
  exit 1
fi

grep -Fq 'cycle_id=' "$ROOT/diagnostics/final-certification"
grep -Fq 'This physical suspend/resume cycle is already recorded' "$ROOT/diagnostics/final-certification"
grep -Fq 'marker_ts >= post_ts' "$ROOT/diagnostics/final-certification"
grep -Fq 'latest-post.log' "$ROOT/diagnostics/final-certification"

grep -Fq 'Current mode' "$ROOT/diagnostics/display-doctor"
grep -Fq 'current_mode=' "$ROOT/diagnostics/display-doctor"
grep -Fq 'DISPLAY_CERT_TOLERANCE_HZ' "$ROOT/diagnostics/display-doctor"

grep -Fq 'blocked_physical_ipv4' "$ROOT/scripts/kvm/runtime_certification.sh"
grep -Fq 'Ubuntu → physical LAN' "$ROOT/scripts/kvm/runtime_certification.sh"
grep -Fq 'KVM LAN guard' "$ROOT/scripts/kvm/runtime_certification.sh"

grep -Fq 'clinfo' "$ROOT/diagnostics/arc-compute-doctor"
grep -Fq 'intel-level-zero' "$ROOT/diagnostics/arc-compute-doctor"

grep -Fq 'packages-desktop-integration.txt' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'packages-desktop-integration.txt' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'gnome-shell-extension-appindicator' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'test_desktop_lifecycle_contract.sh' "$ROOT/.github/workflows/tests.yml"

echo 'Desktop/lifecycle completion contract: PASS'
