#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
doctor="$ROOT/diagnostics/ptyxis-doctor"

grep -Fxq 'ptyxis' "$ROOT/manifests/packages-applications-gtk4.txt"
for token in 'org.gnome.Ptyxis.desktop' 'org.gnome.Ptyxis' 'Bash login shell' 'TERMINAL_PACKAGE'; do
  grep -Fq "$token" "$doctor" || { echo "Ptyxis doctor missing contract token: $token" >&2; exit 1; }
done

grep -Fq 'diagnostics/ptyxis-doctor' "$ROOT/modules/applications/49_applications_validation.sh"
grep -Fq 'diagnostics/ptyxis-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'diagnostics/ptyxis-doctor' "$ROOT/diagnostics/workstation-doctor"
grep -Fq 'ptyxis --version' "$ROOT/.github/workflows/desktop-integration-pretest.yml"

# Toolbx remains intentionally outside the Golden HOST until explicitly enabled
# by a future policy; KVM is still the primary DevOps isolation boundary.
if grep -Fxq 'toolbox' "$ROOT/manifests/packages-shell.txt"; then
  echo 'Toolbx must not become an implicit HOST dependency' >&2
  exit 1
fi

echo 'ptyxis contract: PASS'
