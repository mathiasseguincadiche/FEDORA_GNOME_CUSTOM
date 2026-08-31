#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED='org.gnome.Nautilus.desktop brave-browser.desktop org.gnome.Ptyxis.desktop code.desktop com.bitwarden.desktop.desktop com.slack.Slack.desktop libreoffice-startcenter.desktop org.gnome.Software.desktop'

grep -Fq 'GNOME_DOCK_FAVORITES_ENABLED="true"' "$ROOT/config/gnome.conf"
grep -Fq "GNOME_DOCK_FAVORITES=\"$EXPECTED\"" "$ROOT/config/gnome.conf"
grep -Fq 'applications.dock_favorites|APPLICATIONS|applications.professional|modules/applications/42_dock_favorites.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.validation|APPLICATIONS|applications.dock_favorites|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'gsettings set org.gnome.shell favorite-apps' "$ROOT/scripts/gnome/configure-dock-favorites.sh"
grep -Fq 'Dock launcher is not exported' "$ROOT/modules/applications/42_dock_favorites.sh"
grep -Fq 'com.bitwarden.desktop.desktop' "$ROOT/config/gnome.conf"
grep -Fq 'com.slack.Slack.desktop' "$ROOT/config/gnome.conf"
grep -Fq 'applications-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'test_dock_favorites_contract.sh' "$ROOT/.github/workflows/tests.yml"
grep -Fq 'Validate curated GNOME dock policy' "$ROOT/.github/workflows/fedora-host-pretest.yml"

if grep -Fq 'org.remmina.Remmina.desktop' "$ROOT/config/gnome.conf"; then
  echo 'Remmina must remain installed but not pinned by the curated dock policy' >&2
  exit 1
fi

echo 'curated GNOME dock favorites contract: PASS'
