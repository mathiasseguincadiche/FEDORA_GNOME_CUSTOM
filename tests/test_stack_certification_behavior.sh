#!/usr/bin/env bash
# Stack certification run for real: the complete driver contract on a fixture
# sysfs with fake lspci/modinfo/lsmod/rpm (every Golden device bound to its
# in-tree Fedora driver, no NVIDIA stack), its fingerprint, and the effective
# configuration hash that certificates are bound to.
# shellcheck disable=SC2016,SC1090,SC1091,SC2031
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "stack certification behavior: FAIL: $*" >&2; exit 1; }

# Fixture sysfs: the Arc B580 on xe and the two T705 on nvme.
sys="$tmp/sys"
gpu="$sys/bus/pci/devices/0000:03:00.0"
mkdir -p "$gpu" "$sys/bus/pci/drivers/xe" "$sys/bus/pci/drivers/vfio-pci" "$sys/bus/pci/drivers/nvme"
printf '0x8086\n' > "$gpu/vendor"; printf '0xe20b\n' > "$gpu/device"
ln -s "$sys/bus/pci/drivers/xe" "$gpu/driver"
for n in 0 1; do
  mkdir -p "$sys/class/nvme/nvme$n/device"
  printf 'CT1000T705SSD3      \n' > "$sys/class/nvme/nvme$n/model"
  ln -s "$sys/bus/pci/drivers/nvme" "$sys/class/nvme/nvme$n/device/driver"
done
printf 'pci_id=14c3:7927\ndriver=mt7925e\n' > "$tmp/wifi-identity.env"
export HARDWARE_SYSFS_ROOT="$sys" T_TMP="$tmp"

mkdir -p "$tmp/bin"
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake lspci 'printf "%s\n" "0000:05:00.0 Ethernet controller [0200]: Realtek RTL8126 [10ec:8126]" "	Kernel driver in use: ${T_LAN_DRIVER:-r8169}" \
  "0000:0c:00.0 USB controller [0c03]: AMD USB 3.2 [1022:43f7]" "	Kernel driver in use: ${T_USB_DRIVER:-xhci_hcd}"'
# modinfo: built-in drivers (T_BUILTIN) report filename "(builtin)" and no intree tag,
# like the real modinfo; loadable ones report intree=Y, or N for T_EXTERNAL.
fake modinfo 'case "$1 $2" in
  "-F filename") [[ " ${T_BUILTIN:-} " == *" $3 "* ]] && echo "(builtin)" || echo "/lib/modules/k/kernel/$3.ko.xz" ;;
  "-F intree") [[ " ${T_BUILTIN:-} " == *" $3 "* ]] && exit 0; [[ "$3" == "${T_EXTERNAL:-}" ]] && echo N || echo Y ;;
  *) exit 1 ;;
esac'
fake lsmod 'printf "%s\n" "Module Size Used" "xe 1 0" ${T_NVIDIA:+"nvidia_drm 1 0"}'
fake rpm 'for pkg in "${@:2}"; do [[ "$pkg" != "${T_RPM_INSTALLED:-}" ]] || exit 0; done; exit 1'
export PATH="$tmp/bin:$PATH"

source "$ROOT/lib/driver_contract.sh"
runtime_is_baremetal() { [[ "${T_RUNTIME:-baremetal}" == baremetal ]]; }
hardware_platform_validate_dmi() { [[ -z "${T_DMI_BAD:-}" ]]; }
hardware_platform_wifi_lock_valid() { [[ -z "${T_WIFI_LOCK_BAD:-}" ]]; }
hardware_platform_wifi_lock_path() { echo "$T_TMP/wifi-identity.env"; }

driver_contract_validate || fail 'complete Golden driver stack refused'
refused() { local why="$1"; shift; if env "$@" bash -c "$(declare -f); driver_contract_validate"; then fail "driver contract accepted $why"; fi; }
refused 'a VM runtime' T_RUNTIME=vm
refused 'another motherboard' T_DMI_BAD=1
refused 'an unenrolled Wi-Fi controller' T_WIFI_LOCK_BAD=1
refused 'the LAN on an out-of-tree r8125' T_LAN_DRIVER=r8125
refused 'USB without xhci_hcd' T_USB_DRIVER=vfio-pci
for module in xe r8169 nvme xhci_hcd snd_usb_audio nct6683 mt7925e; do
  refused "an out-of-tree $module" T_EXTERNAL="$module"
done
# Drivers built into the kernel image are in-tree; a loadable one still needs intree=Y.
env T_BUILTIN='xhci_hcd nvme' bash -c "$(declare -f); driver_contract_validate" || fail 'built-in xhci_hcd/nvme refused as out-of-tree'
refused 'a built-in xhci_hcd beside an out-of-tree r8169' T_BUILTIN=xhci_hcd T_EXTERNAL=r8169
refused 'a loaded NVIDIA module' T_NVIDIA=1
refused 'akmod-nvidia installed' T_RPM_INSTALLED=akmod-nvidia
refused 'the NVIDIA X driver installed' T_RPM_INSTALLED=xorg-x11-drv-nvidia
ln -sfn "$sys/bus/pci/drivers/vfio-pci" "$gpu/driver"
refused 'the B580 on vfio-pci'
ln -sfn "$sys/bus/pci/drivers/xe" "$gpu/driver"
printf 'Samsung 990 PRO\n' > "$sys/class/nvme/nvme1/model"
refused 'a single target NVMe'
printf 'CT1000T705SSD3\n' > "$sys/class/nvme/nvme1/model"
printf 'pci_id=14c3:7927\n' > "$tmp/wifi-identity.env"
refused 'a Wi-Fi lock without its driver'
printf 'pci_id=14c3:7927\ndriver=mt7925e\n' > "$tmp/wifi-identity.env"
driver_contract_validate || fail 'restored driver stack refused'

# The driver fingerprint follows the bound drivers and in-tree status.
base="$(driver_contract_fingerprint)"
[[ "$(driver_contract_fingerprint)" == "$base" ]] || fail 'driver fingerprint not deterministic'
[[ "$(T_EXTERNAL=r8169 driver_contract_fingerprint)" != "$base" ]] || fail 'driver fingerprint ignores an out-of-tree module'
ln -sfn "$sys/bus/pci/drivers/vfio-pci" "$gpu/driver"
[[ "$(driver_contract_fingerprint)" != "$base" ]] || fail 'driver fingerprint ignores the GPU binding'
ln -sfn "$sys/bus/pci/drivers/xe" "$gpu/driver"

# Effective configuration hash: every versioned input, nothing else.
fixture="$tmp/repo"
mkdir -p "$fixture"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
hash() { (REPO_ROOT="$fixture"; source "$ROOT/lib/evidence.sh"; effective_config_sha256); }
config_base="$(hash)"
[[ "$config_base" =~ ^[0-9a-f]{64}$ && "$(hash)" == "$config_base" ]] || fail 'effective configuration hash not a stable SHA-256'
for input in config/performance-runtime.policy config/repos/tailscale.repo config/gaming.conf manifests/packages-gaming.txt \
  manifests/module-plan.conf manifests/application-runtime-contract.tsv installer/fedora44-media.lock; do
  cp "$fixture/$input" "$tmp/saved"
  printf '\n# drift\n' >> "$fixture/$input"
  [[ "$(hash)" != "$config_base" ]] || fail "effective configuration ignores $input"
  cp "$tmp/saved" "$fixture/$input"
done
xml="$(cd "$fixture" && find virtualization/xml -name '*.xml' | head -n1)"
[[ -n "$xml" ]] || fail 'no versioned KVM XML found'
printf '<!-- drift -->\n' >> "$fixture/$xml"
[[ "$(hash)" != "$config_base" ]] || fail "effective configuration ignores $xml"
git -C "$ROOT" show "HEAD:$xml" > "$fixture/$xml" 2>/dev/null || cp "$ROOT/$xml" "$fixture/$xml"
[[ "$(hash)" == "$config_base" ]] || fail 'effective configuration not restored'
for unrelated in README.md docs/README.md tests/test_stack_certification_contract.sh; do
  printf '\nunrelated\n' >> "$fixture/$unrelated"
done
[[ "$(hash)" == "$config_base" ]] || fail 'documentation or tests changed the effective configuration'
printf 'X="1"\n' > "$fixture/config/zz-new.conf"
[[ "$(hash)" != "$config_base" ]] || fail 'a new configuration file was ignored'

echo 'stack certification behavior: PASS'
