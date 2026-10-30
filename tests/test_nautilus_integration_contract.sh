#!/usr/bin/env bash
# Nautilus specification: the Golden package sets, backends kept out of the
# GNOME core manifest, the opt-in IBus default and CI wiring. The module,
# prewarm, thumbnail policy and doctor are exercised by
# test_nautilus_integration_behavior.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
base="$ROOT/manifests/packages-nautilus.txt"
optional="$ROOT/manifests/packages-nautilus-optional.txt"

for pkg in nautilus gvfs gvfs-gphoto2 gvfs-fuse file-roller gvfs-afc gvfs-goa gvfs-nfs sushi file-roller-nautilus; do
  grep -Fxq "$pkg" "$base" || { echo "missing Nautilus Golden package: $pkg" >&2; exit 1; }
done
if grep -Fxq gvfs-archive "$base"; then echo "removed Fedora 45 archive backend requested" >&2; exit 1; fi
for pkg in gvfs-smb gvfs-mtp; do
  grep -Fxq "$pkg" "$optional" || { echo "missing optional Nautilus backend: $pkg" >&2; exit 1; }
done

for pkg in gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse; do
  if grep -Fxq "$pkg" "$ROOT/manifests/packages-gnome.txt"; then
    echo "Nautilus backend leaked back into GNOME core manifest: $pkg" >&2
    exit 1
  fi
done

grep -Fq 'REMOVE_IBUS_TYPING_BOOSTER="false"' "$ROOT/config/performance.conf"
grep -Fq 'diagnostics/nautilus-integration-doctor' "$ROOT/diagnostics/final-certification"
for workflow in fedora-package-preflight.yml fedora-host-pretest.yml desktop-integration-pretest.yml; do
  grep -Fq 'manifests/packages-nautilus.txt' "$ROOT/.github/workflows/$workflow" || {
    echo "workflow does not consume Nautilus manifest: $workflow" >&2
    exit 1
  }
done
grep -Fq 'file-roller-nautilus' "$ROOT/.github/workflows/desktop-integration-pretest.yml"
grep -Fq 'test_nautilus_integration_behavior.sh' "$ROOT/.github/workflows/tests.yml"

echo 'nautilus integration contract: PASS'
