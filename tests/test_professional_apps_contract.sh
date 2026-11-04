#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

grep -Fq 'PROFESSIONAL_APPLICATION_EXCEPTIONS="true"' "$ROOT/config/applications.conf"
grep -Fq 'ENABLE_PROFESSIONAL_APPLICATIONS="true"' "$ROOT/config/applications.conf"
grep -Fq 'ENABLE_PROFESSIONAL_FLATPAKS="true"' "$ROOT/config/applications.conf"
grep -Fq 'TEXT_EDITOR_PACKAGE="gnome-text-editor"' "$ROOT/config/applications.conf"
if grep -Eq '^(org[.]onlyoffice[.]desktopeditors|com[.]collaboraoffice[.]Office)$' "$ROOT/manifests/flatpaks-applications-professional.txt"; then
  echo 'unexpected alternative office suite in Flatpak manifest' >&2
  exit 1
fi

for pkg in vlc libreoffice libreoffice-langpack-fr libreoffice-gtk4 filezilla; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-applications-professional-fedora.txt" || { echo "missing Fedora professional app: $pkg" >&2; exit 1; }
done

for pkg in code brave-browser; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-applications-professional-vendor.txt" || { echo "missing vendor professional app: $pkg" >&2; exit 1; }
done

for app in com.bitwarden.desktop com.slack.Slack com.github.marktext.marktext com.jgraph.drawio.desktop; do
  grep -Fxq "$app" "$ROOT/manifests/flatpaks-applications-professional.txt" || { echo "missing professional Flatpak: $app" >&2; exit 1; }
done

grep -Fq 'packages.microsoft.com/yumrepos/vscode' "$ROOT/config/repos/vscode.repo"
grep -Fq 'packages.microsoft.com/keys/microsoft.asc' "$ROOT/config/repos/vscode.repo"
grep -Fq 'brave-browser-rpm-release.s3.brave.com' "$ROOT/config/repos/brave-browser.repo"
grep -Fq 'gpgcheck=1' "$ROOT/config/repos/vscode.repo"
grep -Fq 'gpgcheck=1' "$ROOT/config/repos/brave-browser.repo"

grep -Fq 'applications.professional|APPLICATIONS|applications.gtk4|modules/applications/41_professional_apps.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.appimage|APPLICATIONS|applications.professional|modules/applications/43_appimage_compat.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.dock_favorites|APPLICATIONS|applications.appimage|modules/applications/42_dock_favorites.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.validation|APPLICATIONS|applications.dock_favorites|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'packages-applications-professional-fedora.txt' "$ROOT/modules/applications/41_professional_apps.sh"
grep -Fq 'packages-applications-professional-vendor.txt' "$ROOT/modules/applications/41_professional_apps.sh"
grep -Fq 'flatpaks-applications-professional.txt' "$ROOT/modules/applications/41_professional_apps.sh"

! grep -RInE --exclude-dir=.git '(curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh)' "$ROOT/modules/applications" "$ROOT/config/repos" || {
  echo 'unmanaged pipe-to-shell installer found in professional app scope' >&2
  exit 1
}

# Every Flatpak that a Gate 3 check requires must be one the project installs.
installed_flatpaks="$(cat "$ROOT"/manifests/flatpaks-*.txt | sed -E '/^[[:space:]]*(#|$)/d')"
while IFS=$'\t' read -r kind id _; do
  [[ "$kind" == flatpak ]] || continue
  grep -Fxq "$id" <<<"$installed_flatpaks" || { echo "runtime contract requires a Flatpak no manifest installs: $id" >&2; exit 1; }
done < "$ROOT/manifests/application-runtime-contract.tsv"
usage_ids="$(sed -nE 's/^for id in (.*); do$/\1/p' "$ROOT/diagnostics/application-usage-doctor")"
[[ -n "$usage_ids" ]] || { echo 'application-usage-doctor Flatpak list not found' >&2; exit 1; }
for id in $usage_ids; do
  grep -Fxq "$id" <<<"$installed_flatpaks" || { echo "application-usage-doctor requires a Flatpak no manifest installs: $id" >&2; exit 1; }
done

echo 'professional applications contract: PASS'
