#!/usr/bin/env bash
# Desktop ergonomics specification: package sources and CI wiring. The DING and
# Show Desktop install, settings, postcheck and gnome-doctor behaviour is
# exercised by test_desktop_ergonomics_behavior.sh and
# test_extension_variants_behavior.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="$(<"$ROOT/VERSION")"
[[ "$(printf '%s
%s
' '0.12.0' "$version" | sort -V | head -n1)" == "0.12.0" ]]

# Fedora 45 does not package DING; the reviewed GNOME artifact is unpacked with unzip.
if grep -Fxq 'gnome-shell-extension-desktop-icons-ng' "$ROOT/manifests/packages-gnome-extensions.txt"; then
  echo 'DING must not be declared as a Fedora RPM on Fedora 45' >&2
  exit 1
fi
grep -Fxq 'xdg-user-dirs' "$ROOT/manifests/packages-gnome.txt"
grep -Fxq 'unzip' "$ROOT/manifests/packages-system.txt"

# Real GNOME 51 schemas are exercised by the Fedora host/package CI.
grep -Fq 'source config/gnome-extensions.lock' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'bash .github/scripts/gnome51-settings-pretest.sh' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'gnome_ding_settings_apply' "$ROOT/.github/scripts/gnome51-settings-pretest.sh"
grep -Fq 'gnome_show_desktop_button_settings_check' "$ROOT/.github/scripts/gnome51-settings-pretest.sh"
grep -Fq 'test_desktop_ergonomics_behavior.sh' "$ROOT/.github/workflows/tests.yml"

echo 'Desktop ergonomics contract: PASS'
