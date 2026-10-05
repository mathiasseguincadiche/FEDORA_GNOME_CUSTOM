#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/peripheral_identity.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
STATE_ROOT="$tmp/state"
hardware_platform_sysfs_root(){ printf '%s\n' "$tmp/sys"; }
hardware_platform_board_name(){ echo MS-7E61; }
hardware_platform_validate_dmi(){ return 0; }
runtime_is_baremetal(){ return 0; }
evidence_atomic_write(){ cat > "$1"; chmod "$2" "$1"; }
mkdir -p "$tmp/sys/class/sound/card2" "$tmp/sys/devices/audio/interface" "$tmp/sys/drivers/snd_usb_audio"
printf '0db0\n' > "$tmp/sys/devices/audio/idVendor"
printf 'cc78\n' > "$tmp/sys/devices/audio/idProduct"
printf 'USB Audio\n' > "$tmp/sys/devices/audio/product"
ln -s "$tmp/sys/drivers/snd_usb_audio" "$tmp/sys/devices/audio/interface/driver"
ln -s "$tmp/sys/devices/audio/interface" "$tmp/sys/class/sound/card2/device"
peripheral_enroll audio card2
[[ "$(peripheral_resolve audio)" == card2 ]]
# ALSA enumeration changes across boot; resolve the same USB identity.
mv "$tmp/sys/class/sound/card2" "$tmp/sys/class/sound/card5"
[[ "$(peripheral_resolve audio)" == card5 ]]
printf '046d\n' > "$tmp/sys/devices/audio/idVendor"
if peripheral_resolve audio; then echo 'Webcam mic was accepted as motherboard audio' >&2; exit 1; fi
printf '0db0\n' > "$tmp/sys/devices/audio/idVendor"
printf '9999\n' > "$tmp/sys/devices/audio/idProduct"
if peripheral_resolve audio; then echo 'USB identity drift was accepted' >&2; exit 1; fi
printf 'cc78\n' > "$tmp/sys/devices/audio/idProduct"
printf '0bda\n' > "$tmp/sys/devices/audio/idVendor"
if peripheral_enroll audio card5; then echo 'Generic Realtek audio was enrolled as MSI ALC4080' >&2; exit 1; fi
printf '0db0\n' > "$tmp/sys/devices/audio/idVendor"
mkdir -p "$tmp/sys/class/video4linux/video0" "$tmp/sys/devices/camera/interface" "$tmp/sys/drivers/uvcvideo"
printf '046d\n' > "$tmp/sys/devices/camera/idVendor"
printf '0940\n' > "$tmp/sys/devices/camera/idProduct"
printf 'Brio 100\n' > "$tmp/sys/devices/camera/product"
ln -s "$tmp/sys/drivers/uvcvideo" "$tmp/sys/devices/camera/interface/driver"
ln -s "$tmp/sys/devices/camera/interface" "$tmp/sys/class/video4linux/video0/device"
v4l2-ctl(){ echo 'Video Capture'; }
peripheral_enroll camera video0
[[ "$(peripheral_resolve camera)" == video0 ]]
mkdir -p "$tmp/sys/class/video4linux/video2"
ln -s "$tmp/sys/devices/camera/interface" "$tmp/sys/class/video4linux/video2/device"
if peripheral_resolve camera; then echo 'Ambiguous capture endpoints accepted' >&2; exit 1; fi
rm -rf "$tmp/sys/class/video4linux/video2"
printf 'Generic camera\n' > "$tmp/sys/devices/camera/product"
if peripheral_resolve camera; then echo 'Wrong webcam accepted' >&2; exit 1; fi
mkdir -p "$tmp/sys/class/ieee80211/phy0" "$tmp/sys/devices/0000:0a:00.0"
ln -s "$tmp/sys/devices/0000:0a:00.0" "$tmp/sys/class/ieee80211/phy0/device"
[[ "$(peripheral_wifi_phy 0000:0a:00.0)" == phy0 ]]
if peripheral_wifi_phy 0000:0b:00.0; then echo 'Wrong Wi-Fi PHY accepted' >&2; exit 1; fi
runtime_is_baremetal(){ return 1; }
if peripheral_enroll audio card5; then echo 'Virtual enrollment was accepted' >&2; exit 1; fi
echo 'Peripheral identity behavior: PASS'
