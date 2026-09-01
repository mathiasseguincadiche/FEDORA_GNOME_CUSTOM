#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'ENABLE_GNOME_EXTENSIONS="true"' "$ROOT/config/gnome.conf"
grep -Fq 'ENABLE_DASH_TO_DOCK="true"' "$ROOT/config/gnome.conf"
grep -Fq 'DASH_TO_DOCK_PACKAGE="gnome-shell-extension-dash-to-dock"' "$ROOT/config/gnome.conf"
grep -Fq 'DASH_TO_DOCK_UUID="dash-to-dock@micxgx.gmail.com"' "$ROOT/config/gnome.conf"
grep -Fq 'ENABLE_BLUR_MY_SHELL="false"' "$ROOT/config/gnome.conf"
grep -Fq 'BLUR_MY_SHELL_PACKAGE="gnome-shell-extension-blur-my-shell"' "$ROOT/config/gnome.conf"
grep -Fq 'INSTALL_EXTENSION_MANAGER="true"' "$ROOT/config/gnome.conf"
grep -Fq 'ENABLE_JUST_PERFECTION="false"' "$ROOT/config/gnome.conf"
grep -Fxq 'gnome-shell-extension-dash-to-dock' "$ROOT/manifests/packages-gnome-extensions.txt"
grep -Fq 'gnome_extension_enable_checked' "$ROOT/modules/gnome/24_gnome_extensions.sh"
grep -Fq 'Just Perfection is explicitly excluded' "$ROOT/modules/gnome/24_gnome_extensions.sh"

# External GNOME extension downloads remain forbidden everywhere except the one
# dedicated installer whose exact GNOME review artifact is covered by the
# desktop ergonomics contract.
! grep -RInE --exclude-dir=.git --exclude='install-show-desktop-plus.sh' '(extensions\.gnome\.org.*curl|curl.*extensions\.gnome\.org|wget.*extensions\.gnome\.org|unzip.*gnome-shell/extensions)' "$ROOT/modules/gnome" "$ROOT/scripts" || { echo 'Unmanaged GNOME extension download detected' >&2; exit 1; }
! grep -RInE --exclude-dir=.git 'just-perfection@|gnome-shell-extension-just-perfection' "$ROOT/config" "$ROOT/manifests" "$ROOT/modules" || { echo 'Just Perfection must remain excluded' >&2; exit 1; }
echo 'GNOME Golden extension contract: PASS'
