#!/usr/bin/env bash
# Hardware and KVM completion run for real in a repository copy with fake
# hardware commands and a fixture sysfs: the CPU/memory module keeps the
# nct6683 force option opt-in, firmware packages follow the detected CPU and
# Arc GPU without flashing anything, the hardware components doctor demands
# 5G LAN, Wi-Fi 7 on 6 GHz and xHCI, the USB resume doctor reads the journal,
# and the KVM I/O benchmark selects the faster engine on an idle /data.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "hardware kvm behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/sysroot" "$tmp/data"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/home/.local/state" T_LOG="$tmp/calls" T_TMP="$tmp" T_SYSROOT="$tmp/sysroot" T_SYS="$tmp/sys"
unset XDG_CONFIG_HOME

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"
args=(); for arg in "$@"; do [[ "$arg" != /etc/* ]] || arg="$T_SYSROOT$arg"; args+=("$arg"); done
case "$1" in
  install|chown) exec "${args[@]}" ;;
  virsh) [[ -z "${T_RUNNING:-}" ]] || echo rocky-devops ;;
  dmidecode) [[ -n "${T_NO_DMI:-}" ]] || printf "\tConfigured Memory Speed: %s\n" "${T_RAM_SPEED:-6000 MT/s}" ;;
esac'
fake lspci 'case "$*" in
  "-Dn") [[ -z "${T_NO_ARC:-}" ]] && echo "0000:03:00.0 0300: 8086:e20b" ;;
  "-s 0000:05:00.0 -nn") echo "05:00.0 Ethernet controller [0200]: Realtek RTL8126 5GbE [10ec:8126]" ;;
  "-Dnnk") printf "%s\n" "0000:0c:00.0 USB controller [0c03]: AMD 600 Series USB 3.2 Controller [1022:43f7]" \
      "	Kernel driver in use: ${T_USB_DRIVER:-xhci_hcd}" "" \
      "0000:05:00.0 Ethernet controller [0200]: Realtek RTL8126 5GbE [10ec:8126]" "	Kernel driver in use: r8169" ;;
esac'
fake ethtool 'printf "%s\n" "Settings for $1:" "	Supported link modes:   1000baseT/Full" ${T_NO_5G:+} "	                        ${T_NO_5G:-5000baseT/Full}" "	Speed: ${T_SPEED:-5000Mb/s}"'
fake iw 'printf "%s\n" "Wiphy phy0" "	Band 2:" "		EHT Iftypes: ${T_NO_EHT:-managed}" "	Band 4:" "			* ${T_FREQ:-5955} MHz [1] (23.0 dBm)" | grep -v "EHT Iftypes: none"'
fake bluetoothctl 'echo "Controller AA:BB:CC:DD:EE:FF fixture [default]"'
fake wpctl 'echo " ├─ Audio"'
fake lsmod 'echo "snd_usb_audio 1 0"'
fake lscpu 'echo "Model name: ${T_CPU:-AMD Ryzen 7 7700 8-Core Processor}"'
fake rpm 'for missing in ${T_MISSING:-}; do [[ "$2" != "$missing" ]] || exit 1; done'
fake fwupdmgr 'printf "fwupdmgr %s\n" "$*" >> "$T_LOG"'
fake findmnt 'case "$*" in *TARGET*) echo "${T_MOUNT:-$T_TMP/data}" ;; *FSTYPE*) echo "${T_FSTYPE:-ext4}" ;; esac'
fake fio 'printf "fio %s\n" "$*" >> "$T_LOG"
for arg; do case "$arg" in --ioengine=*) engine="${arg#*=}" ;; --output=*) out="${arg#*=}" ;; --filename=*) file="${arg#*=}" ;; esac; done
: > "$file"
iops=$T_NATIVE_IOPS; [[ "$engine" != io_uring ]] || iops=$T_URING_IOPS
printf "{\"jobs\": [{\"read\": {\"iops\": %s}, \"write\": {\"iops\": 0}}]}\n" "$iops" > "$out"'
for command in dnf journalctl lsusb aplay ip sensors virsh; do fake "$command" ':'; done
export PATH="$tmp/bin:$PATH"

# Fixture sysfs: one r8169 NIC, the loopback has no device.
mkdir -p "$T_SYS/class/net/lo" "$T_SYS/devices/pci0000:00/0000:05:00.0" "$T_SYS/bus/pci/drivers/r8169"
mkdir -p "$T_SYS/class/net/enp5s0"
ln -s "$T_SYS/devices/pci0000:00/0000:05:00.0" "$T_SYS/class/net/enp5s0/device"
ln -s "$T_SYS/bus/pci/drivers/r8169" "$T_SYS/devices/pci0000:00/0000:05:00.0/driver"

# Fixture engine: deterministic runtime and enrolled identities.
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
kernel_journal_require_clean() { return "${T_JOURNAL_RC:-0}"; }
hardware_platform_validate_dmi() { return 0; }
hardware_platform_validate_cpu_power() { return "${T_CPU_POWER_RC:-0}"; }
hardware_platform_validate_hwmon() { return "${T_HWMON_RC:-0}"; }
hardware_platform_hwmon_counts() { printf 'temps=6\nfans=3\n'; }
for field in board_vendor board_name bios_vendor bios_version bios_date cpu_scaling_driver cpu_pstate_status cpu_boost_value; do
  eval "hardware_platform_$field() { echo fixture; }"
done
hardware_platform_wifi_block() { echo '0000:0a:00.0 Network controller [0280]: MEDIATEK MT7927 [14c3:7927]'; }
hardware_platform_wifi_identity_value() { case "$1" in pci_id) echo 14c3:7927 ;; driver) echo mt7925e ;; esac; }
hardware_platform_wifi_lock_valid() { return "${T_WIFI_LOCK_RC:-0}"; }
peripheral_wifi_phy() { echo phy0; }
peripheral_resolve() { case "$1" in audio) echo card1 ;; camera) echo video0 ;; esac; }
physical_bluetooth_identity() { echo 'usb=0e8d:0717 driver=btusb'; }
physical_bluetooth_lock_valid() { return 0; }
physical_cooling_list() { :; }
physical_cooling_lock_valid() { return 0; }
SH
# Host paths the engines hardcode point into the fixture.
sed -i 's|/sys/class/net/\*|$T_SYS/class/net/*|' "$fixture/diagnostics/hardware-components-doctor"
sed -i 's|/var/lib/fedora-gnome-custom/suspend/latest-post.log|$T_TMP/latest-post.log|' "$fixture/diagnostics/usb-resume-doctor"
sed -i 's|/proc/meminfo|"$T_TMP/meminfo"|' "$fixture/modules/hardware/10_cpu_memory.sh"
sed -i 's|/proc/cpuinfo|"$T_TMP/cpuinfo"|g' "$fixture/modules/system/02_firmware_microcode.sh"
grep -Fq '$T_SYS/class/net' "$fixture/diagnostics/hardware-components-doctor" && grep -Fq '$T_TMP/meminfo' "$fixture/modules/hardware/10_cpu_memory.sh" \
  && grep -Fq '$T_TMP/cpuinfo' "$fixture/modules/system/02_firmware_microcode.sh" && grep -Fq '$T_TMP/latest-post' "$fixture/diagnostics/usb-resume-doctor" \
  || fail 'cannot redirect the hardcoded host paths'
printf 'KVM_DATA_MOUNT="%s"\n' "$tmp/data" > "$fixture/config/local.conf"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
source "$fixture/config/hardware.conf"; source "$fixture/config/hardware-components.conf"
log_info() { :; }; log_warn() { :; }; log_error() { :; }
install_manifest_packages() { printf 'packages %s\n' "${2##*/}" >> "$T_LOG"; }

# CPU/memory: Fedora's in-tree nct6683, forced only on explicit opt-in.
source "$fixture/modules/hardware/10_cpu_memory.sh"
[[ "$HARDWARE_NCT6683_FORCE" == false ]] || fail 'nct6683 force is not opt-in'
calls() { grep '^sudo \(install\|modprobe\)' "$T_LOG" | paste -sd'|'; }
rm -f "$T_LOG"; DRY_RUN=false hardware_cpu_memory_apply
[[ "$(calls)" == "sudo install -Dm0644 $fixture/systemd/modules-load.d/fedora-gnome-custom-hwmon.conf /etc/modules-load.d/fedora-gnome-custom-hwmon.conf|sudo modprobe nct6683" ]] \
  || fail "default hwmon apply ran: $(calls)"
[[ "$(grep -v '^#' "$T_SYSROOT/etc/modules-load.d/fedora-gnome-custom-hwmon.conf")" == nct6683 && ! -e "$T_SYSROOT/etc/modprobe.d" ]] \
  || fail 'default apply did not load plain nct6683 at boot'
grep -Fxq 'packages packages-hardware.txt' "$T_LOG" || fail 'hardware observability packages not installed'
rm -f "$T_LOG"; HARDWARE_NCT6683_FORCE=true DRY_RUN=false hardware_cpu_memory_apply
[[ "$(calls)" == *"|sudo install -Dm0644 $fixture/systemd/modprobe.d/fedora-gnome-custom-nct6683-force.conf /etc/modprobe.d/fedora-gnome-custom-nct6683-force.conf|sudo modprobe -r nct6683|sudo modprobe nct6683" ]] \
  || fail "force opt-in did not reload nct6683 with its option: $(calls)"
grep -Fxq 'options nct6683 force=1' "$T_SYSROOT/etc/modprobe.d/fedora-gnome-custom-nct6683-force.conf" || fail 'force option file not installed'
rm -rf "${T_SYSROOT:?}/etc"; rm -f "$T_LOG"; DRY_RUN=true hardware_cpu_memory_apply
[[ ! -e "$T_SYSROOT/etc" ]] && ! grep -qs '^sudo' "$T_LOG" || fail 'preflight hardware apply mutated the host'
printf 'MemTotal:       49283072 kB\n' > "$tmp/meminfo"
postcheck() { local rc=0; DRY_RUN=false hardware_cpu_memory_postcheck || rc=$?; echo "$rc"; }
[[ "$(postcheck)" == 0 ]] || fail '48 GiB Ryzen 7 7700 refused'
[[ "$(T_NO_DMI=1 postcheck)" == 0 && "$(T_RAM_SPEED='4800 MT/s' postcheck)" == 0 ]] || fail 'memory speed inventory must stay informational'
[[ "$(T_CPU='AMD Ryzen 5 7600' postcheck)" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'another CPU accepted'
[[ "$(T_CPU_POWER_RC=1 postcheck)" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'AMD P-State/boost failure accepted'
[[ "$(T_HWMON_RC=1 postcheck)" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'missing hwmon telemetry accepted'
printf 'MemTotal:       32768000 kB\n' > "$tmp/meminfo"
[[ "$(postcheck)" == "$EXIT_POSTCHECK_FAILED" ]] || fail '32 GiB accepted'

# Firmware: packages follow the CPU vendor and the Arc B580; fwupd only inventories.
source "$fixture/modules/system/02_firmware_microcode.sh"
firmware() { rm -f "$T_LOG"; DRY_RUN=false system_firmware_apply; grep '^sudo dnf' "$T_LOG"; }
echo 'vendor_id : AuthenticAMD' > "$tmp/cpuinfo"
[[ "$(firmware)" == 'sudo dnf -y install fwupd linux-firmware amd-ucode-firmware intel-gpu-firmware' ]] || fail "AMD + Arc firmware: $(firmware)"
echo 'vendor_id : GenuineIntel' > "$tmp/cpuinfo"
[[ "$(T_NO_ARC=1 firmware)" == 'sudo dnf -y install fwupd linux-firmware microcode_ctl' ]] || fail "Intel firmware: $(T_NO_ARC=1 firmware)"
echo 'vendor_id : AuthenticAMD' > "$tmp/cpuinfo"
rm -f "$T_LOG"; DRY_RUN=false system_firmware_postcheck || fail 'firmware postcheck failed'
[[ "$(grep '^fwupdmgr' "$T_LOG")" == 'fwupdmgr get-devices' ]] || fail 'fwupd did more than inventory devices'
for missing in amd-ucode-firmware intel-gpu-firmware; do
  rc=0; T_MISSING="$missing" DRY_RUN=false system_firmware_postcheck || rc=$?
  [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "firmware postcheck passed without $missing"
done

# Hardware components doctor.
components() { bash "$fixture/diagnostics/hardware-components-doctor" > "$tmp/out" 2>&1; }
components || { cat "$tmp/out" >&2; fail 'complete hardware refused'; }
grep -Fq 'enp5s0 bdf=0000:05:00.0 pci=[10ec:8126] driver=r8169' "$tmp/out" || fail '5G LAN not identified through sysfs'
blocked() { # blocked WHY ENV... : the doctor must fail
  local why="$1" rc=0; shift
  env "$@" bash "$fixture/diagnostics/hardware-components-doctor" --quiet > /dev/null 2>&1 || rc=$?
  [[ "$rc" != 0 ]] || fail "hardware components doctor accepted $why"
}
blocked 'a LAN without 5000baseT' T_NO_5G=1000baseT/Full
blocked 'Wi-Fi without EHT' T_NO_EHT=none
blocked 'Wi-Fi without 6 GHz channels' T_FREQ=5180
blocked 'an unenrolled Wi-Fi controller' T_WIFI_LOCK_RC=1
blocked 'USB controllers without xhci_hcd' T_USB_DRIVER=vfio-pci
blocked 'missing NCT6687D telemetry' T_HWMON_RC=1
T_SPEED=1000Mb/s components || fail 'a 1 Gb/s link partner must only warn'
grep -Fq 'link equipment may limit it' "$tmp/out" || fail 'slow negotiated LAN speed not reported'
printf 'HARDWARE_REQUIRE_WIFI7_CAPABILITY="false"\nKVM_DATA_MOUNT="%s"\n' "$tmp/data" > "$fixture/config/local.conf"
T_NO_EHT=none components || fail 'Wi-Fi 7 requirement not configurable'
printf 'KVM_DATA_MOUNT="%s"\n' "$tmp/data" > "$fixture/config/local.conf"
mv "$T_SYS/class/net/enp5s0" "$tmp/enp5s0"; blocked 'a missing r8169 interface'; mv "$tmp/enp5s0" "$T_SYS/class/net/enp5s0"

# USB resume doctor: xHCI bound and a clean journal; sleep-hook evidence is advisory.
usb() { bash "$fixture/diagnostics/usb-resume-doctor" > "$tmp/out" 2>&1; }
usb || fail 'clean USB resume refused'
grep -Fq 'no post-resume log yet' "$tmp/out" || fail 'missing sleep-hook log not reported'
printf '[usb-xhci] 0000:0c:00.0 ok\n' > "$tmp/latest-post.log"; usb && grep -Fq 'Sleep-hook USB evidence' "$tmp/out" || fail 'sleep-hook evidence not read'
rc=0; T_JOURNAL_RC=1 usb || rc=$?; [[ "$rc" != 0 ]] || fail 'xHCI errors in the journal accepted'
rc=0; T_USB_DRIVER=vfio-pci usb || rc=$?; [[ "$rc" != 0 ]] || fail 'unbound xHCI accepted'

# KVM I/O benchmark: idle EXT4 /data on bare metal, the faster engine wins.
state="$XDG_STATE_HOME/fedora-gnome-custom/kvm-io-profile.env"
io() { rm -f "$T_LOG"; bash "$fixture/diagnostics/kvm-io-doctor" "$@" > "$tmp/out" 2>&1; }
rc=0; io --quiet || rc=$?; [[ "$rc" == 1 ]] || fail 'unbenchmarked I/O profile passed'
T_URING_IOPS=90000 T_NATIVE_IOPS=70000 io benchmark || { cat "$tmp/out" >&2; fail 'benchmark failed'; }
grep -Fxq KVM_IO_SELECTED_PROFILE=io_uring "$state" || fail 'faster io_uring not selected'
[[ "$(grep -c '^fio ' "$T_LOG")" == 2 ]] && grep -q -- '--ioengine=io_uring' "$T_LOG" && grep -q -- '--ioengine=libaio' "$T_LOG" || fail 'both engines not measured'
grep -q -- "--filename=$tmp/data/libvirt/benchmarks/kvm-io-test.bin" "$T_LOG" || fail 'benchmark not on /data'
[[ ! -e "$tmp/data/libvirt/benchmarks/kvm-io-test.bin" ]] || fail 'benchmark file left on /data'
io --quiet || fail 'benchmarked profile not accepted'
T_URING_IOPS=50000 T_NATIVE_IOPS=70000 io benchmark && grep -Fxq KVM_IO_SELECTED_PROFILE=native "$state" || fail 'faster native AIO not selected'
refused() { # refused WHY ENV... : no benchmark runs
  local why="$1" rc=0; shift
  rm -f "$T_LOG"
  env T_URING_IOPS=1 T_NATIVE_IOPS=1 "$@" bash "$fixture/diagnostics/kvm-io-doctor" benchmark > /dev/null 2>&1 || rc=$?
  [[ "$rc" != 0 ]] && ! grep -qs '^fio ' "$T_LOG" || fail "benchmark ran with $why"
}
refused 'a running VM' T_RUNNING=1
refused 'a non-EXT4 /data' T_FSTYPE=btrfs
refused '/data not mounted' T_MOUNT=/
refused 'a VM runtime' T_RUNTIME=vm
printf 'KVM_IO_SELECTED_PROFILE=threads\n' > "$state"
rc=0; io --quiet || rc=$?; [[ "$rc" == 1 ]] || fail 'unknown I/O profile accepted'

echo 'hardware kvm behavior: PASS'
