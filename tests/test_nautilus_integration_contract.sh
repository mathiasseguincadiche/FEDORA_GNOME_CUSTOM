#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
base="$ROOT/manifests/packages-nautilus.txt"
optional="$ROOT/manifests/packages-nautilus-optional.txt"
module="$ROOT/modules/gnome/21_nautilus_integration.sh"
doctor="$ROOT/diagnostics/nautilus-integration-doctor"

for pkg in nautilus gvfs gvfs-gphoto2 gvfs-fuse gvfs-archive gvfs-afc gvfs-goa gvfs-nfs sushi file-roller-nautilus; do
  grep -Fxq "$pkg" "$base" || { echo "missing Nautilus Golden package: $pkg" >&2; exit 1; }
done
for pkg in gvfs-smb gvfs-mtp; do
  grep -Fxq "$pkg" "$optional" || { echo "missing optional Nautilus backend: $pkg" >&2; exit 1; }
done

for pkg in gvfs-smb gvfs-mtp gvfs-gphoto2 gvfs-fuse; do
  if grep -Fxq "$pkg" "$ROOT/manifests/packages-gnome.txt"; then
    echo "Nautilus backend leaked back into GNOME core manifest: $pkg" >&2
    exit 1
  fi
done

grep -Fq 'manifests/packages-nautilus.txt' "$module"
grep -Fq 'NAUTILUS_ENABLE_SMB' "$module"
grep -Fq 'NAUTILUS_ENABLE_MTP' "$module"
grep -Fq 'NAUTILUS_ENABLE_PREVIEWS' "$module"
grep -Fq 'NAUTILUS_PREVIEW_POLICY' "$module"
grep -Fq 'diagnostics/nautilus-integration-doctor' "$module"
if grep -Fq 'ibus-typing-booster' "$module"; then
  echo 'IBus workaround must not be coupled to Nautilus' >&2
  exit 1
fi

grep -Fq 'REMOVE_IBUS_TYPING_BOOSTER="false"' "$ROOT/config/performance.conf"
grep -Fq 'REMOVE_IBUS_TYPING_BOOSTER' "$ROOT/modules/desktop/26_desktop_integration.sh"

for token in gvfs-archive gvfs-afc gvfs-goa gvfs-nfs sushi file-roller-nautilus 'show-image-thumbnails' 'fedora-gnome-nautilus-prewarm.service'; do
  grep -Fq "$token" "$doctor" || { echo "Nautilus doctor missing check: $token" >&2; exit 1; }
done

grep -Fq 'diagnostics/nautilus-integration-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'manifests/packages-nautilus.txt' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'file-roller-nautilus' "$ROOT/.github/workflows/desktop-integration-pretest.yml"

echo 'nautilus integration contract: PASS'
