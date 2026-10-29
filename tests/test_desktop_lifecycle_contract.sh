#!/usr/bin/env bash
# Desktop lifecycle specification: the owner's update policy, the desktop
# integration package set, module order and certification wiring. Behaviour is
# exercised by test_desktop_lifecycle_behavior.sh (lifecycle module and doctor,
# AppIndicator, suspend cycles, Arc compute) and the backup behaviour tests.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "desktop lifecycle contract: FAIL: $*" >&2; exit 1; }

version="$(<"$ROOT/VERSION")"
[[ "$(printf '%s\n%s\n' '0.9.0' "$version" | sort -V | head -n1)" == 0.9.0 ]] || fail "VERSION below 0.9.0: $version"

(
  set +u
  source "$ROOT/config/desktop.conf"; source "$ROOT/config/backup.conf"; source "$ROOT/config/gnome.conf"
  [[ "$LIFECYCLE_AUTOMATIC_DOWNLOADS" == true && "$LIFECYCLE_AUTOMATIC_INSTALLS" == false \
    && "$LIFECYCLE_AUTOMATIC_REBOOT" == never && "$LIFECYCLE_FLATPAK_UPDATE_POLICY" == manual ]] || fail 'update policy changed'
  [[ "$DAILY_BACKUP_ENABLED" == true && "$ENABLE_APPINDICATOR" == true ]] || fail 'daily backup or AppIndicator disabled'
)

for pkg in gnome-keyring gnome-keyring-pam libsecret cups ipp-usb avahi sane-airscan NetworkManager-openvpn NetworkManager-openconnect tuned-ppd glibc-langpack-fr hunspell-fr liberation-fonts-all remmina libimobiledevice intel-compute-runtime intel-level-zero intel-opencl clinfo dnf5-plugin-automatic; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-desktop-integration.txt" || fail "desktop integration package missing: $pkg"
done

# Persistent data sits between GNOME validation and the desktop integration/lifecycle layers.
for entry in 'desktop.persistent_data|DESKTOP|gnome.validation|modules/desktop/25_persistent_data.sh' \
  'desktop.integration|DESKTOP|desktop.persistent_data|modules/desktop/26_desktop_integration.sh' \
  'desktop.lifecycle|DESKTOP|desktop.integration|' 'backup.daily|BACKUP|backup.validation|'; do
  grep -Fq "$entry" "$ROOT/manifests/module-plan.conf" || fail "module order changed: $entry"
done
for doctor in desktop-integration-doctor portal-doctor arc-compute-doctor lifecycle-doctor daily-backup-doctor; do
  grep -Fq "diagnostics/$doctor" "$ROOT/diagnostics/final-certification" || fail "final certification skips $doctor"
done

grep -Fxq 'OnCalendar=daily' "$ROOT/systemd/user/fedora-gnome-daily-backup.timer" || fail 'daily backup timer is not daily'
if grep -Fq -- '--prune' "$ROOT/scripts/backup/daily-user-backup.sh"; then fail 'daily backup must not prune snapshots automatically'; fi
grep -Fq 'runtime_certification_core.sh' "$ROOT/scripts/kvm/runtime_certification.sh" || fail 'KVM runtime certification bypasses its strict core'

# The Fedora package preflights resolve the desktop integration set.
for workflow in fedora-package-preflight fedora-host-pretest; do
  grep -Fq 'packages-desktop-integration.txt' "$ROOT/.github/workflows/$workflow.yml" || fail "$workflow skips the desktop packages"
done
grep -Fq 'gnome-shell-extension-appindicator' "$ROOT/.github/workflows/fedora-package-preflight.yml" || fail 'AppIndicator not preflighted'

echo 'Desktop/lifecycle completion contract: PASS'
