#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "appimage contract: FAIL: $*" >&2; exit 1; }

fedora_manifest=manifests/packages-appimage.txt
flatpak_manifest=manifests/flatpaks-appimage.txt
module=modules/applications/43_appimage_compat.sh
doctor=diagnostics/appimage-doctor
runner=scripts/appimage/appimage-run
workflow=.github/workflows/fedora-appimage-pretest.yml

for f in "$fedora_manifest" "$flatpak_manifest" "$module" "$doctor" "$runner" "$workflow" docs/APPIMAGE.md; do
  [[ -s "$f" ]] || fail "missing $f"
done

for pkg in fuse fuse-libs.x86_64 fuse-libs.i686 fuse3 fuse3-libs.x86_64 fuse3-libs.i686 bsdtar squashfs-tools file desktop-file-utils shared-mime-info xdg-utils; do
  grep -Fxq "$pkg" "$fedora_manifest" || fail "$pkg missing from AppImage manifest"
done
grep -Fxq 'it.mijorus.gearlever' "$flatpak_manifest" || fail 'Gear Lever missing from AppImage Flatpak manifest'

grep -Fq 'applications.appimage|APPLICATIONS|applications.professional|modules/applications/43_appimage_compat.sh' manifests/module-plan.conf || fail 'AppImage module missing from applications chain'
grep -Fq 'applications.dock_favorites|APPLICATIONS|applications.appimage|modules/applications/42_dock_favorites.sh' manifests/module-plan.conf || fail 'dock favorites must depend on AppImage integration'

grep -Fq 'AI\001' "$doctor" || fail 'doctor Type 1 synthetic probe missing'
grep -Fq 'AI\002' "$doctor" || fail 'doctor Type 2 synthetic probe missing'
grep -Fq 'runtime_is_baremetal' "$doctor" || fail 'doctor must distinguish physical FUSE evidence'

grep -Fq '414901' "$runner" || fail 'Type 1 marker missing from runner'
grep -Fq '414902' "$runner" || fail 'Type 2 marker missing from runner'
grep -Fq 'APPIMAGE_EXTRACT_AND_RUN=1' "$runner" || fail 'Type 2 no-FUSE fallback missing'
grep -Fq 'bsdtar -xf' "$runner" || fail 'Type 1 extraction fallback missing'

if grep -Eqi 'setenforce[[:space:]]+0|disable.*selinux|chmod[[:space:]]+777|modprobe[[:space:]].*fuse.*\|\|[[:space:]]*true' "$module" "$runner"; then
  fail 'unsafe global compatibility workaround detected'
fi

grep -Fq 'manifests/packages-appimage.txt' "$workflow" || fail 'AppImage CI must consume RPM manifest'
grep -Fq 'manifests/flatpaks-appimage.txt' "$workflow" || fail 'AppImage CI must validate integration Flatpak'
grep -Fq 'fedora:44' "$workflow" || fail 'AppImage CI must run on Fedora 44'
grep -Fq -- '--identify' "$workflow" || fail 'AppImage CI must validate Type 1/Type 2 detection without launching untrusted payloads'

echo 'appimage contract: PASS'
