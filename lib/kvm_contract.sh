#!/usr/bin/env bash

kvm_contract_expected_io() {
  local state="${KVM_IO_PROFILE_STATE:-${HOME}/.local/state/fedora-gnome-custom/kvm-io-profile.env}" selected=""
  if [[ -r "$state" ]]; then
    selected="$(awk -F= '$1=="KVM_IO_SELECTED_PROFILE" {print $2; exit}' "$state")"
  fi
  case "$selected" in io_uring|native|threads) printf '%s\n' "$selected" ;; *) printf '%s\n' "${VM_DISK_IO_DEFAULT:-io_uring}" ;; esac
}

kvm_contract_validate_domcaps_file() {
  local xml="$1"
  [[ -s "$xml" ]] || return 1
  python3 - "$xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
def text(path):
    node = root.find(path)
    return (node.text or '').strip() if node is not None else ''
def fail(msg):
    print(msg, file=sys.stderr); raise SystemExit(1)
if root.tag != 'domainCapabilities': fail('unexpected domcaps root')
if text('domain') != 'kvm': fail('KVM domain type unavailable')
if text('arch') != 'x86_64': fail('x86_64 KVM unavailable')
if 'q35' not in text('machine').lower(): fail('q35 machine unavailable')
host_passthrough = root.find("./cpu/mode[@name='host-passthrough']")
if host_passthrough is None or host_passthrough.get('supported') != 'yes': fail('host-passthrough CPU unavailable')
os_node = root.find('./os')
if os_node is None or os_node.get('supported') != 'yes': fail('guest OS capability unavailable')
firmware_values = {(v.text or '').strip().lower() for e in root.findall(".//enum[@name='firmware']") for v in e.findall('value')}
loader_values = [(v.text or '').strip().lower() for v in root.findall('.//loader/value')]
if 'efi' not in firmware_values and not any('ovmf' in v or v.endswith('.fd') for v in loader_values): fail('EFI/OVMF unavailable')
tpm = root.find('./devices/tpm')
if tpm is None or tpm.get('supported') != 'yes': fail('TPM device unsupported')
tpm_values = {(v.text or '').strip() for v in tpm.findall('.//value')}
if 'tpm-crb' not in tpm_values: fail('TPM CRB model unavailable')
if 'emulator' not in tpm_values: fail('TPM emulator backend unavailable')
PY
}

kvm_contract_validate_guest_file() {
  local profile="$1" xml="$2" expected_io="${3:-$(kvm_contract_expected_io)}"
  [[ -s "$xml" ]] || return 1
  python3 - "$profile" "$xml" "${KVM_NETWORK_NAME:-devops-nat}" "${KVM_POOL_PATH:-/data/libvirt/images}" "$expected_io" "${UBUNTU_SERVER_NAME:-ubuntu-devops}" "${UBUNTU_SERVER_VCPU:-6}" "${UBUNTU_SERVER_RAM_MB:-16384}" "${WINDOWS11_NAME:-windows-11}" "${WINDOWS11_VCPU:-4}" "${WINDOWS11_RAM_MB:-12288}" <<'PY'
import sys
import xml.etree.ElementTree as ET
(profile, path, network, pool_path, expected_io, ubuntu_name, ubuntu_vcpu, ubuntu_ram, windows_name, windows_vcpu, windows_ram) = sys.argv[1:]
root = ET.parse(path).getroot()
def fail(msg):
    print(msg, file=sys.stderr); raise SystemExit(1)
def memory_mib(node):
    if node is None or not (node.text or '').strip().isdigit(): return None
    value=int((node.text or '').strip()); unit=(node.get('unit') or 'KiB').lower()
    factors={'b':1/1048576,'bytes':1/1048576,'kib':1/1024,'kb':1/1024,'mib':1,'mb':1,'gib':1024,'gb':1024}
    return round(value*factors.get(unit,1/1024))
if root.tag != 'domain': fail('unexpected domain XML')
name=(root.findtext('name') or '').strip()
if profile=='ubuntu': expected_name, expected_vcpu, expected_ram=ubuntu_name,int(ubuntu_vcpu),int(ubuntu_ram)
elif profile=='windows': expected_name, expected_vcpu, expected_ram=windows_name,int(windows_vcpu),int(windows_ram)
else: fail('unknown profile')
if name != expected_name: fail(f'domain name mismatch: {name}')
os_type=root.find('./os/type')
if os_type is None or os_type.get('arch')!='x86_64' or 'q35' not in (os_type.get('machine') or '').lower(): fail('domain must use x86_64 q35')
cpu=root.find('./cpu')
if cpu is None or cpu.get('mode')!='host-passthrough': fail('CPU is not host-passthrough')
vcpu=root.find('./vcpu')
if vcpu is None or int((vcpu.text or '0').strip()) != expected_vcpu: fail('vCPU count mismatch')
if memory_mib(root.find('./memory')) != expected_ram: fail('memory size mismatch')
if root.find('./devices/hostdev') is not None: fail('host device passthrough is forbidden')
interfaces=root.findall("./devices/interface[@type='network']")
if not any(i.find('source') is not None and i.find('source').get('network')==network and i.find('model') is not None and i.find('model').get('type')=='virtio' for i in interfaces): fail('VirtIO network or libvirt network mismatch')
main_disk=None; expected_disk=f"{pool_path.rstrip('/')}/{expected_name}.qcow2"
for disk in root.findall("./devices/disk[@device='disk']"):
    src=disk.find('source')
    if src is not None and src.get('file')==expected_disk: main_disk=disk; break
if main_disk is None: fail(f'main qcow2 disk mismatch: {expected_disk}')
driver=main_disk.find('driver'); target=main_disk.find('target')
if driver is None or driver.get('type')!='qcow2' or driver.get('cache')!='none' or driver.get('discard')!='unmap': fail('disk driver/cache/discard contract mismatch')
if expected_io and driver.get('io') != expected_io: fail(f'disk I/O mismatch: expected {expected_io}')
if target is None or target.get('bus')!='virtio': fail('main disk is not VirtIO')
channels=root.findall('./devices/channel')
if not any(c.find('target') is not None and c.find('target').get('name')=='org.qemu.guest_agent.0' for c in channels): fail('QEMU Guest Agent channel missing')
if not any((r.get('model') or '')=='virtio' for r in root.findall('./devices/rng')): fail('VirtIO RNG missing')
balloon=root.find('./devices/memballoon')
if balloon is None or balloon.get('model')!='virtio': fail('VirtIO balloon missing')
if profile=='ubuntu':
    if root.find('./devices/graphics') is not None: fail('Ubuntu DevOps must remain headless')
else:
    tpm=root.find('./devices/tpm'); backend=tpm.find('backend') if tpm is not None else None
    if tpm is None or tpm.get('model')!='tpm-crb' or backend is None or backend.get('type')!='emulator' or backend.get('version')!='2.0': fail('Windows TPM 2.0 CRB emulator mismatch')
    features={f.get('name'):f.get('enabled') for f in root.findall('./os/firmware/feature')}; loader=root.find('./os/loader'); secure_loader=loader is not None and loader.get('secure')=='yes'
    if features.get('secure-boot')!='yes' and not secure_loader: fail('Windows Secure Boot missing')
    if features.get('enrolled-keys')!='yes': fail('Windows enrolled Secure Boot keys missing')
    if not any(g.get('type')=='spice' for g in root.findall('./devices/graphics')): fail('Windows SPICE graphics missing')
    if not any(c.find('target') is not None and c.find('target').get('name')=='com.redhat.spice.0' for c in channels): fail('Windows SPICE agent channel missing')
PY
}

kvm_contract_xml_sha256() {
  local uri="$1" kind="$2" name="$3" xml
  case "$kind" in
    domain) xml="$(virsh --connect "$uri" dumpxml --inactive "$name" 2>/dev/null || true)" ;;
    network) xml="$(virsh --connect "$uri" net-dumpxml "$name" 2>/dev/null || true)" ;;
    pool) xml="$(virsh --connect "$uri" pool-dumpxml "$name" 2>/dev/null || true)" ;;
    *) return 1 ;;
  esac
  [[ -n "$xml" ]] || { printf 'missing\n'; return 0; }
  printf '%s\n' "$xml" | sha256sum | awk '{print $1}'
}

kvm_contract_fingerprint_payload() {
  local uri="${LIBVIRT_URI:-qemu:///system}"
  printf 'io=%s\n' "$(kvm_contract_expected_io)"
  if ! command -v virsh >/dev/null 2>&1 || ! virsh --connect "$uri" list --all >/dev/null 2>&1; then printf 'libvirt=unavailable\n'; return; fi
  printf 'network=%s\n' "$(kvm_contract_xml_sha256 "$uri" network "${KVM_NETWORK_NAME:-devops-nat}")"
  printf 'pool=%s\n' "$(kvm_contract_xml_sha256 "$uri" pool "${KVM_POOL_NAME:-devops-data}")"
  printf 'ubuntu=%s\n' "$(kvm_contract_xml_sha256 "$uri" domain "${UBUNTU_SERVER_NAME:-ubuntu-devops}")"
  printf 'windows=%s\n' "$(kvm_contract_xml_sha256 "$uri" domain "${WINDOWS11_NAME:-windows-11}")"
}

kvm_contract_fingerprint() { kvm_contract_fingerprint_payload | sha256sum | awk '{print $1}'; }
