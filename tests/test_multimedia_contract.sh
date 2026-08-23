#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for pkg in gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugin-openh264 libvpl intel-vpl-gpu-rt; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-multimedia-fedora.txt" || { echo "missing Fedora multimedia package: $pkg" >&2; exit 1; }
done
for pkg in ffmpegthumbnailer gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-rpmfusion.txt" || { echo "missing RPM Fusion multimedia package: $pkg" >&2; exit 1; }
done

! grep -Fxq ffmpeg "$ROOT/manifests/packages-rpmfusion.txt" || { echo 'ffmpeg must be converged by explicit provider logic, not generic manifest install' >&2; exit 1; }
grep -Fq 'dnf -y swap ffmpeg-free ffmpeg --allowerasing' "$ROOT/modules/gnome/22_multimedia_codecs.sh"
grep -Fq 'dnf -y swap libva-intel-media-driver intel-media-driver --allowerasing' "$ROOT/modules/gnome/22_multimedia_codecs.sh"
grep -Fq 'INTEL_MEDIA_DRIVER_POLICY="auto"' "$ROOT/config/gnome.conf"
grep -Fq 'multimedia_vaapi_profiles_complete' "$ROOT/modules/gnome/22_multimedia_codecs.sh"
[[ -f "$ROOT/diagnostics/media-doctor" ]]
echo 'multimedia contract: PASS'
