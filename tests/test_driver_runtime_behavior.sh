#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/driver_contract.sh
source "$ROOT/lib/driver_contract.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export HARDWARE_SYSFS_ROOT="$tmp/sys"
mkdir -p "$tmp/sys/bus/pci/devices/0000:03:00.0" "$tmp/sys/bus/pci/drivers/xe"
printf '0x8086\n' > "$tmp/sys/bus/pci/devices/0000:03:00.0/vendor"
printf '0xe20b\n' > "$tmp/sys/bus/pci/devices/0000:03:00.0/device"
ln -s "$tmp/sys/bus/pci/drivers/xe" "$tmp/sys/bus/pci/devices/0000:03:00.0/driver"
[[ "$(driver_contract_pci_driver_for_id 8086 e20b)" == xe ]]
rm "$tmp/sys/bus/pci/devices/0000:03:00.0/driver"
if driver_contract_pci_driver_for_id 8086 e20b >/dev/null 2>&1; then echo 'unbound B580 was accepted' >&2; exit 1; fi
ln -s "$tmp/sys/bus/pci/drivers/xe" "$tmp/sys/bus/pci/devices/0000:03:00.0/driver"

mkdir -p "$tmp/bin"
cat > "$tmp/bin/modinfo" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == -F && "$2" == intree ]]; then
  [[ "${BAD_MODULE:-}" == "${3:-}" ]] && { echo N; exit 0; }
  echo Y
  exit 0
fi
exit 1
SH
chmod +x "$tmp/bin/modinfo"
PATH="$tmp/bin:$PATH"
driver_contract_module_intree xe
if BAD_MODULE=xe driver_contract_module_intree xe; then echo 'external xe module was accepted' >&2; exit 1; fi

mkdir -p "$tmp/sys/bus/pci/drivers/nvme"
for n in 0 1; do
  mkdir -p "$tmp/sys/class/nvme/nvme$n/device"
  printf 'CT1000T705SSD3\n' > "$tmp/sys/class/nvme/nvme$n/model"
  ln -s "$tmp/sys/bus/pci/drivers/nvme" "$tmp/sys/class/nvme/nvme$n/device/driver"
done
EXPECTED_NVME_MODEL=CT1000T705SSD3 EXPECTED_NVME_COUNT=2 driver_contract_nvme_expected_bound
printf 'OTHER-SSD\n' > "$tmp/sys/class/nvme/nvme1/model"
if EXPECTED_NVME_MODEL=CT1000T705SSD3 EXPECTED_NVME_COUNT=2 driver_contract_nvme_expected_bound; then echo 'wrong NVMe inventory was accepted' >&2; exit 1; fi

echo 'driver runtime behavior: PASS'
