#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/config/virtualization.conf"
source "$REPO_ROOT/config/hardware-components.conf"
source "$REPO_ROOT/config/vm-profiles.conf"

uri="${LIBVIRT_URI:-qemu:///system}"
ubuntu="${UBUNTU_SERVER_NAME:-ubuntu-devops}"
windows="${WINDOWS11_NAME:-windows-11}"
network="${KVM_NETWORK_NAME:-devops-nat}"
username="${UBUNTU_SERVER_USERNAME:-mathias}"
guard_unit="fedora-gnome-custom-kvm-guard.service"
guard_helper="/usr/local/libexec/fedora-gnome-custom/kvm-network-guard"
ok=0
warn=0
ko=0

record() {
  printf '%-4s %-32s %s\n' "$1" "$2" "$3"
  case "$1" in
    OK) ((ok+=1)) ;;
    WARN) ((warn+=1)) ;;
    KO) ((ko+=1)) ;;
  esac
}

vsh() { sudo virsh --connect "$uri" "$@"; }

domain_ip() {
  local dom="$1" ip="" mac=""
  ip="$(vsh domifaddr "$dom" --source agent 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')"
  if [[ -z "$ip" ]]; then
    mac="$(vsh domiflist "$dom" 2>/dev/null | awk -v net="$network" '$3 == net {print $5; exit}')"
    if [[ -n "$mac" ]]; then
      ip="$(vsh net-dhcp-leases "$network" 2>/dev/null | awk -v mac="$mac" '$0 ~ mac && $0 ~ /ipv4/ {sub(/\/.*/, "", $5); print $5; exit}')"
    fi
  fi
  printf '%s' "$ip"
}

domain_xml_has() { vsh dumpxml "$1" 2>/dev/null | grep -Eq "$2"; }
agent_ping() { vsh qemu-agent-command "$1" '{"execute":"guest-ping"}' >/dev/null 2>&1; }
remote_ping() {
  local target="$1"
  printf '%s\n' "$target" | ssh "${ssh_base[@]}" "${username}@${ubuntu_ip}" 'read -r target; ping -c 1 -W 2 "$target" >/dev/null'
}

for dom in "$ubuntu" "$windows"; do
  if vsh dominfo "$dom" >/dev/null 2>&1; then record OK "domain $dom" present; else record KO "domain $dom" missing; fi
done
((ko == 0)) || exit 1

for dom in "$ubuntu" "$windows"; do
  if domain_xml_has "$dom" 'org.qemu.guest_agent.0'; then record OK "$dom QGA channel" present; else record KO "$dom QGA channel" missing; fi
  if domain_xml_has "$dom" '<rng'; then record OK "$dom VirtIO RNG" present; else record KO "$dom VirtIO RNG" missing; fi
  if domain_xml_has "$dom" '<memballoon[^>]+model=.virtio.'; then record OK "$dom balloon" virtio; else record KO "$dom balloon" missing; fi
  if agent_ping "$dom"; then record OK "$dom guest agent" responding; else record KO "$dom guest agent" 'guest-ping failed'; fi
done

if domain_xml_has "$windows" 'secure-boot' && domain_xml_has "$windows" '<tpm'; then record OK 'Windows security devices' 'Secure Boot + TPM present'; else record KO 'Windows security devices' missing; fi
if domain_xml_has "$windows" 'com.redhat.spice.0'; then record OK 'Windows SPICE channel' present; else record KO 'Windows SPICE channel' missing; fi
if domain_xml_has "$windows" "network=.${network}.|source network=.${network}." && domain_xml_has "$windows" "model type=.virtio."; then record OK 'Windows VirtIO network' configured; else record KO 'Windows VirtIO network' mismatch; fi
if domain_xml_has "$windows" "target[^>]+bus=.virtio."; then record OK 'Windows VirtIO disk' configured; else record KO 'Windows VirtIO disk' mismatch; fi

if [[ "${KVM_BLOCK_PHYSICAL_LAN:-true}" == true ]]; then
  if sudo systemctl is-active --quiet "$guard_unit"; then
    record OK 'KVM guard service' active
  else
    record KO 'KVM guard service' inactive
  fi

  if [[ -x "$guard_helper" ]]; then
    if sudo systemctl reload "$guard_unit" >/dev/null 2>&1; then
      record OK 'KVM guard reconcile' 'reload completed through emergency state'
    else
      record KO 'KVM guard reconcile' 'reload failed; inspect systemctl/journalctl before continuing'
    fi

    guard_check="$(sudo "$guard_helper" check 2>/dev/null || true)"
    if grep -Fq 'guard_mode=normal' <<<"$guard_check"; then
      record OK 'KVM guard mode' normal
    else
      record KO 'KVM guard mode' "$(grep '^guard_mode=' <<<"$guard_check" | cut -d= -f2- || printf unknown)"
    fi
  else
    guard_check=""
    record KO 'KVM guard helper' missing
  fi

  nft_guard="$(sudo nft list table inet "${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}" 2>/dev/null || true)"
  if grep -Fq 'blocked_physical_ipv4' <<<"$nft_guard" \
    && grep -Fq 'normal block VM to physical LAN' <<<"$nft_guard" \
    && grep -Fq 'normal block physical LAN to VM' <<<"$nft_guard" \
    && grep -Fq "${KVM_BRIDGE_NAME:-virbr50}" <<<"$nft_guard"; then
    record OK 'KVM LAN guard rules' 'bidirectional forwarding isolation loaded'
  else
    record KO 'KVM LAN guard rules' 'normal nft isolation rules missing'
  fi

  physical_networks="$(awk -F= '$1=="physical_networks" {print $2}' <<<"$guard_check")"
  if [[ -n "$physical_networks" && "$physical_networks" != none-connected ]]; then
    coverage_ok=true
    IFS=',' read -r -a physical_cidrs <<<"$physical_networks"
    for cidr in "${physical_cidrs[@]}"; do
      grep -Fq "$cidr" <<<"$nft_guard" || coverage_ok=false
    done
    if [[ "$coverage_ok" == true ]]; then
      record OK 'KVM LAN CIDR coverage' "$physical_networks"
    else
      record KO 'KVM LAN CIDR coverage' "guard does not contain every discovered uplink CIDR: $physical_networks"
    fi
  else
    record WARN 'KVM LAN CIDR coverage' 'no connected physical uplink CIDR to prove'
  fi
fi

ubuntu_ip="$(domain_ip "$ubuntu")"
windows_ip="$(domain_ip "$windows")"
if [[ -n "$ubuntu_ip" ]]; then record OK 'Ubuntu IP' "$ubuntu_ip"; else record KO 'Ubuntu IP' unavailable; fi
if [[ -n "$windows_ip" ]]; then record OK 'Windows IP' "$windows_ip"; else record WARN 'Windows IP' unavailable; fi

physical_gateway="$(ip -4 route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}')"
kvm_gateway="${KVM_GATEWAY:-192.168.50.254}"

ssh_base=(-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new)
if [[ -n "$ubuntu_ip" ]] && ssh "${ssh_base[@]}" "${username}@${ubuntu_ip}" true >/dev/null 2>&1; then
  record OK 'HOST → Ubuntu SSH' reachable

  if ssh "${ssh_base[@]}" "${username}@${ubuntu_ip}" 'sudo /usr/local/sbin/devops-verify.sh' >/dev/null 2>&1; then record OK 'Ubuntu DevOps stack' verified; else record KO 'Ubuntu DevOps stack' failed; fi
  if ssh "${ssh_base[@]}" "${username}@${ubuntu_ip}" 'getent ahostsv4 example.com >/dev/null && curl -fsS --max-time 10 https://example.com >/dev/null'; then record OK 'Ubuntu DNS/Internet' working; else record KO 'Ubuntu DNS/Internet' failed; fi
  if remote_ping "$kvm_gateway"; then record OK 'Ubuntu → KVM gateway' reachable; else record KO 'Ubuntu → KVM gateway' failed; fi

  if [[ "${KVM_BLOCK_PHYSICAL_LAN:-true}" == true && -n "$physical_gateway" ]]; then
    if ping -c 1 -W 2 "$physical_gateway" >/dev/null 2>&1; then
      if remote_ping "$physical_gateway" >/dev/null 2>&1; then
        record KO 'Ubuntu → physical LAN' "live gateway $physical_gateway unexpectedly reachable"
      else
        record OK 'Ubuntu → physical LAN' "live host-reachable gateway blocked ($physical_gateway)"
      fi
    else
      record WARN 'Ubuntu → physical LAN' "host cannot prove gateway $physical_gateway is ping-responsive; nft rules were validated statically"
    fi
  elif [[ "${KVM_BLOCK_PHYSICAL_LAN:-true}" == true ]]; then
    record WARN 'Ubuntu → physical LAN' 'no physical default gateway available for live proof'
  fi
else
  record KO 'HOST → Ubuntu SSH' unavailable
fi

if "$REPO_ROOT/diagnostics/kvm-io-doctor" --quiet; then record OK 'T705 KVM I/O profile' benchmarked; else record WARN 'T705 KVM I/O profile' 'default profile in use'; fi
record WARN 'Windows guest integration' 'inside Windows, Configure-GuestIntegration.ps1 must report healthy VirtIO devices and QEMU-GA'
record WARN 'LAN → VM live proof' 'run the documented second-host test when certifying a new physical LAN; host-side rules are already checked here'

printf '\nRuntime certification summary: OK=%d WARN=%d KO=%d\n' "$ok" "$warn" "$ko"
((ko == 0))
