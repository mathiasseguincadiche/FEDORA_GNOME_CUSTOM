#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p \
  "$tmp/bin" \
  "$tmp/sys/class/dmi/id" \
  "$tmp/sys/devices/system/cpu/cpufreq/policy0" \
  "$tmp/sys/devices/system/cpu/amd_pstate" \
  "$tmp/sys/class/hwmon/hwmon0" \
  "$tmp/state"

printf 'Micro-Star International Co., Ltd.\n' > "$tmp/sys/class/dmi/id/board_vendor"
printf 'MAG B850M MORTAR WIFI (MS-7E61)\n' > "$tmp/sys/class/dmi/id/board_name"
printf 'American Megatrends International, LLC.\n' > "$tmp/sys/class/dmi/id/bios_vendor"
printf 'A.10\n' > "$tmp/sys/class/dmi/id/bios_version"
printf '08/01/2026\n' > "$tmp/sys/class/dmi/id/bios_date"
printf 'amd-pstate-epp\n' > "$tmp/sys/devices/system/cpu/cpufreq/policy0/scaling_driver"
printf '1\n' > "$tmp/sys/devices/system/cpu/cpufreq/policy0/boost"
printf 'active\n' > "$tmp/sys/devices/system/cpu/amd_pstate/status"
printf 'nct6687\n' > "$tmp/sys/class/hwmon/hwmon0/name"
printf '42000\n' > "$tmp/sys/class/hwmon/hwmon0/temp1_input"
printf '1350\n' > "$tmp/sys/class/hwmon/hwmon0/fan1_input"

cat > "$tmp/bin/lscpu" <<'EOF'
#!/usr/bin/env bash
printf 'Model name: AMD Ryzen 7 7700 8-Core Processor\n'
EOF
cat > "$tmp/bin/lspci" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
0000:0a:00.0 Network controller [0280]: Qualcomm Technologies, Inc Device [17cb:1107]
	Kernel driver in use: ath12k_pci
	Kernel modules: ath12k
OUT
EOF
chmod +x "$tmp/bin/lscpu" "$tmp/bin/lspci"

export PATH="$tmp/bin:$PATH"
export HARDWARE_SYSFS_ROOT="$tmp/sys"
STATE_ROOT="$tmp/state"
RUNTIME_ENVIRONMENT=baremetal
EXPECTED_MOTHERBOARD='MAG B850M MORTAR WIFI'
EXPECTED_CPU='AMD Ryzen 7 7700'
EXIT_SECURITY_BLOCK=50
EXIT_PRECHECK_FAILED=20
runtime_is_baremetal() { [[ "$RUNTIME_ENVIRONMENT" == baremetal ]]; }
runtime_is_baremetal

# shellcheck source=lib/evidence.sh
source "$ROOT/lib/evidence.sh"
# shellcheck source=lib/hardware_platform.sh
source "$ROOT/lib/hardware_platform.sh"

hardware_platform_validate_dmi
hardware_platform_validate_cpu_power
hardware_platform_validate_hwmon

if hardware_platform_wifi_lock_valid; then
  echo 'Wi-Fi lock unexpectedly valid before enrollment' >&2
  exit 1
fi
lock="$(hardware_platform_enroll_wifi_identity)"
[[ -s "$lock" ]]
hardware_platform_wifi_lock_valid

# A driver change must invalidate the enrolled physical identity.
sed -i 's/ath12k_pci/other_driver/' "$tmp/bin/lspci"
if hardware_platform_wifi_lock_valid; then
  echo 'Wi-Fi lock accepted a different driver' >&2
  exit 1
fi
sed -i 's/other_driver/ath12k_pci/' "$tmp/bin/lspci"
hardware_platform_wifi_lock_valid

# Disabling boost must fail the strict Ryzen power contract.
printf '0\n' > "$tmp/sys/devices/system/cpu/cpufreq/policy0/boost"
if hardware_platform_validate_cpu_power; then
  echo 'CPU power validation accepted boost=0' >&2
  exit 1
fi
printf '1\n' > "$tmp/sys/devices/system/cpu/cpufreq/policy0/boost"
hardware_platform_validate_cpu_power

# A dead fan tachometer must fail motherboard hwmon certification.
printf '0\n' > "$tmp/sys/class/hwmon/hwmon0/fan1_input"
if hardware_platform_validate_hwmon; then
  echo 'hwmon validation accepted zero live fan tachometers' >&2
  exit 1
fi
printf '1350\n' > "$tmp/sys/class/hwmon/hwmon0/fan1_input"
hardware_platform_validate_hwmon

# Wrong motherboard identity must fail closed.
printf 'OTHER BOARD\n' > "$tmp/sys/class/dmi/id/board_name"
if hardware_platform_validate_dmi; then
  echo 'DMI validation accepted another motherboard' >&2
  exit 1
fi

echo 'hardware platform behavior: PASS'
