#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

grep -Fq 'PROFESSIONAL_APPLICATION_EXCEPTIONS="true"' "$ROOT/config/applications.conf"
grep -Fq 'ENABLE_PROFESSIONAL_APPLICATIONS="true"' "$ROOT/config/applications.conf"
grep -Fq 'ENABLE_PROFESSIONAL_FLATPAKS="true"' "$ROOT/config/applications.conf"
grep -Fq 'TEXT_EDITOR_PACKAGE="gnome-text-editor"' "$ROOT/config/applications.conf"

for pkg in vlc libreoffice libreoffice-langpack-fr filezilla; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-applications-professional-fedora.txt" || { echo "missing Fedora professional app: $pkg" >&2; exit 1; }
done

for pkg in code brave-browser; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-applications-professional-vendor.txt" || { echo "missing vendor professional app: $pkg" >&2; exit 1; }
done

for app in com.bitwarden.desktop com.slack.Slack org.onlyoffice.desktopeditors com.github.marktext.marktext com.jgraph.drawio.desktop; do
  grep -Fxq "$app" "$ROOT/manifests/flatpaks-applications-professional.txt" || { echo "missing professional Flatpak: $app" >&2; exit 1; }
done

grep -Fq 'packages.microsoft.com/yumrepos/vscode' "$ROOT/config/repos/vscode.repo"
grep -Fq 'packages.microsoft.com/keys/microsoft.asc' "$ROOT/config/repos/vscode.repo"
grep -Fq 'brave-browser-rpm-release.s3.brave.com' "$ROOT/config/repos/brave-browser.repo"
grep -Fq 'gpgcheck=1' "$ROOT/config/repos/vscode.repo"
grep -Fq 'gpgcheck=1' "$ROOT/config/repos/brave-browser.repo"

grep -Fq 'applications.professional|APPLICATIONS|applications.gtk4|modules/applications/41_professional_apps.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.dock_favorites|APPLICATIONS|applications.professional|modules/applications/42_dock_favorites.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.validation|APPLICATIONS|applications.dock_favorites|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'packages-applications-professional-fedora.txt' "$ROOT/modules/applications/41_professional_apps.sh"
grep -Fq 'packages-applications-professional-vendor.txt' "$ROOT/modules/applications/41_professional_apps.sh"
grep -Fq 'flatpaks-applications-professional.txt' "$ROOT/modules/applications/41_professional_apps.sh"

! grep -RInE --exclude-dir=.git '(curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh)' "$ROOT/modules/applications" "$ROOT/config/repos" || {
  echo 'unmanaged pipe-to-shell installer found in professional app scope' >&2
  exit 1
}

echo 'professional applications contract: PASS'
