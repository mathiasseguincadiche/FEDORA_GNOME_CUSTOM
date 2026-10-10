#!/usr/bin/env bash
# Behavioral test of the remote-access helpers that can be exercised without hardware:
# the Wake-on-LAN packet, the GDM automatic-login editor and the wired-interface detection.
# shellcheck disable=SC1090,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "remote wol behavior: FAIL: $*" >&2; exit 1; }
wol="$ROOT/scripts/remote/wol-send.py"
gdm="$ROOT/scripts/remote/gdm_autologin.py"

# --- Magic packet: 6 x 0xFF then the MAC repeated 16 times (102 bytes).
packet="$(python3 "$wol" aa:bb:cc:dd:ee:ff --print-packet)"
[[ "${#packet}" == 204 ]] || fail "magic packet must be 102 bytes, got $(( ${#packet} / 2 ))"
[[ "${packet:0:12}" == ffffffffffff ]] || fail 'magic packet must start with six 0xFF bytes'
expected_tail="$(printf 'aabbccddeeff%.0s' $(seq 16))"
[[ "${packet:12}" == "$expected_tail" ]] || fail 'magic packet must repeat the MAC 16 times'
for variant in AA-BB-CC-DD-EE-FF aabbccddeeff; do
  [[ "$(python3 "$wol" "$variant" --print-packet)" == "$packet" ]] || fail "MAC notation $variant must give the same packet"
done
for bad in aa:bb:cc:dd:ee aa:bb:cc:dd:ee:gg aa:bb:cc-dd:ee:ff 'aa:bb:cc:dd:ee:ff;rm' ''; do
  if python3 "$wol" "$bad" --print-packet >/dev/null 2>&1; then fail "invalid MAC accepted: '$bad'"; fi
done
if python3 "$wol" aa:bb:cc:dd:ee:ff --broadcast not-an-ip --print-packet >/dev/null 2>&1; then fail 'invalid broadcast accepted'; fi
if python3 "$wol" aa:bb:cc:dd:ee:ff --broadcast ::1 --print-packet >/dev/null 2>&1; then fail 'IPv6 broadcast accepted'; fi
if python3 "$wol" aa:bb:cc:dd:ee:ff --repeat 99 --print-packet >/dev/null 2>&1; then fail 'out-of-range repeat accepted'; fi

# --- GDM automatic login: idempotent, keeps comments and other sections, refuses root.
conf="$tmp/custom.conf"
printf '# GDM configuration\n[daemon]\n# AutomaticLoginEnable=True\nWaylandEnable=true\n[security]\nDisallowTCP=true\n' > "$conf"
[[ "$(python3 "$gdm" status --file "$conf")" == disabled ]] || fail 'commented autologin must read as disabled'
python3 "$gdm" enable --user mathias --file "$conf"
python3 "$gdm" enable --user mathias --file "$conf"
[[ "$(grep -c '^AutomaticLoginEnable=True' "$conf")" == 1 ]] || fail 'enable must be idempotent'
[[ "$(python3 "$gdm" status --file "$conf")" == 'enabled user=mathias' ]] || fail 'status after enable'
for kept in '# GDM configuration' 'WaylandEnable=true' 'DisallowTCP=true'; do
  grep -Fq "$kept" "$conf" || fail "unrelated GDM setting lost: $kept"
done
python3 "$gdm" enable --user alice --file "$conf"
[[ "$(python3 "$gdm" status --file "$conf")" == 'enabled user=alice' ]] || fail 'enable must replace the previous user'
python3 "$gdm" disable --file "$conf"
[[ "$(python3 "$gdm" status --file "$conf")" == disabled ]] || fail 'status after disable'
grep -Fq 'WaylandEnable=true' "$conf" || fail 'disable must preserve unrelated settings'
printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=original\n' > "$tmp/gdm-original"
python3 "$gdm" enable --user mathias --file "$conf"
python3 "$gdm" disable --file "$conf" --restore-from "$tmp/gdm-original"
[[ "$(python3 "$gdm" status --file "$conf")" == 'enabled user=original' ]] || fail 'existing autologin must be restored from backup'
if python3 "$gdm" enable --user root --file "$conf" 2>/dev/null; then fail 'root automatic login must be refused'; fi
if python3 "$gdm" enable --user 'a;b' --file "$conf" 2>/dev/null; then fail 'invalid user name accepted'; fi
: > "$tmp/empty.conf"
python3 "$gdm" enable --user mathias --file "$tmp/empty.conf"
grep -Fxq '[daemon]' "$tmp/empty.conf" || fail 'enable must create the [daemon] section'
python3 "$gdm" enable --user mathias --file "$tmp/absent.conf"
[[ -s "$tmp/absent.conf" ]] || fail 'enable must create a missing file'

# --- Helpers: ports and wired-interface detection through a fake sysfs.
REPO_ROOT="$ROOT"
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/remote_access.sh"
for good in 22 47984 65535; do remote_valid_port "$good" || fail "port $good must be valid"; done
for bad in 0 65536 047984 -1 abc '' '22;ls'; do if remote_valid_port "$bad"; then fail "port '$bad' must be invalid"; fi; done
remote_valid_port_list '47984 47989 48010' || fail 'valid port list rejected'
if remote_valid_port_list '47984 99999'; then fail 'invalid port list accepted'; fi

sysfs="$tmp/sys"
mkdir -p "$sysfs/class/net/lo" "$sysfs/class/net/wlp6s0/device" "$sysfs/class/net/enp5s0/device" "$sysfs/bus/pci/drivers/ath12k_pci" "$sysfs/bus/pci/drivers/r8169"
ln -s "$sysfs/bus/pci/drivers/ath12k_pci" "$sysfs/class/net/wlp6s0/device/driver"
ln -s "$sysfs/bus/pci/drivers/r8169" "$sysfs/class/net/enp5s0/device/driver"
[[ "$(REMOTE_SYSFS_ROOT="$sysfs" remote_wired_interface)" == enp5s0 ]] || fail 'the r8169 interface must be selected, not Wi-Fi or loopback'
if HARDWARE_LAN_DRIVER=other REMOTE_SYSFS_ROOT="$sysfs" remote_wired_interface; then fail 'an unexpected driver must not match'; fi

echo 'remote wol behavior: PASS'
