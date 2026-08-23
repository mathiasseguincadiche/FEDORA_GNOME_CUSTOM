#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config/virtualization.conf
source "$REPO_ROOT/config/virtualization.conf"
# shellcheck source=config/vm-profiles.conf
source "$REPO_ROOT/config/vm-profiles.conf"

uri="${LIBVIRT_URI:-qemu:///system}"
ubuntu="${UBUNTU_SERVER_NAME:-ubuntu-devops}"
windows="${WINDOWS11_NAME:-windows-11}"
network="${KVM_NETWORK_NAME:-devops-nat}"
username="${UBUNTU_SERVER_USERNAME:-mathias}"
ok=0
warn=0
ko=0

record() {
  local level="$1" label="$2" detail="$3"
  printf '%-4s %-30s %s\n' "$level" "$label" "$detail"
  case "$level" in
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

domain_xml_has() {
  local dom="$1" pattern="$2"
  vsh dumpxml "$dom" 2>/dev/null | grep -Eq "$pattern"
}

for dom in "$ubuntu" "$windows"; do
  if vsh dominfo "$dom" >/dev/null 2>&1; then
    record OK "domain $dom" present
  else
    record KO "domain $dom" missing
  fi
done

if ((ko > 0)); then
  printf '\nRuntime certification cannot continue until both reference guests exist.\n'
  exit 1
fi

if domain_xml_has "$ubuntu" 'type=.virtiofs.|driver[^>]+type=.virtiofs.|<filesystem'; then
  record OK 'Ubuntu VirtioFS XML' present
else
  record KO 'Ubuntu VirtioFS XML' missing
fi

if domain_xml_has "$windows" "feature[^>]+enabled=.yes.[^>]+name=.secure-boot.|name=.secure-boot.[^>]+enabled=.yes."; then
  record OK 'Windows UEFI/Secure Boot XML' present
else
  record KO 'Windows UEFI/Secure Boot XML' not-detected
fi
if domain_xml_has "$windows" '<tpm' && domain_xml_has "$windows" 'version=.2.0.|tpm-crb'; then
  record OK 'Windows TPM 2.0 XML' present
else
  record KO 'Windows TPM 2.0 XML' missing
fi
if domain_xml_has "$windows" "network=.${network}.|source network=.${network}." && domain_xml_has "$windows" "model type=.virtio."; then
  record OK 'Windows VirtIO network' configured
else
  record KO 'Windows VirtIO network' mismatch
fi
if domain_xml_has "$windows" "target[^>]+bus=.virtio."; then
  record OK 'Windows VirtIO disk' configured
else
  record KO 'Windows VirtIO disk' mismatch
fi

ubuntu_ip="$(domain_ip "$ubuntu")"
windows_ip="$(domain_ip "$windows")"
if [[ -n "$ubuntu_ip" ]]; then record OK 'Ubuntu IP' "$ubuntu_ip"; else record KO 'Ubuntu IP' unavailable; fi
if [[ -n "$windows_ip" ]]; then record OK 'Windows IP/lease' "$windows_ip"; else record WARN 'Windows IP/lease' 'not visible; install QEMU guest agent or inspect DHCP lease'; fi

if [[ -n "$ubuntu_ip" ]]; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${username}@${ubuntu_ip}" true >/dev/null 2>&1; then
    record OK 'HOST → Ubuntu SSH' reachable
    if ssh -o BatchMode=yes "${username}@${ubuntu_ip}" 'sudo /usr/local/sbin/devops-verify.sh' >/dev/null 2>&1; then
      record OK 'Ubuntu DevOps stack' verified
    else
      record KO 'Ubuntu DevOps stack' 'guest verification failed'
    fi
    if ssh -o BatchMode=yes "${username}@${ubuntu_ip}" 'getent ahostsv4 example.com >/dev/null'; then
      record OK 'Ubuntu DNS' working
    else
      record KO 'Ubuntu DNS' failed
    fi
    if ssh -o BatchMode=yes "${username}@${ubuntu_ip}" 'curl -fsS --max-time 10 https://example.com >/dev/null'; then
      record OK 'Ubuntu → Internet' working
    else
      record KO 'Ubuntu → Internet' failed
    fi

    host_bridge_ip="$(ip -4 -o addr show "${KVM_BRIDGE_NAME:-virbr50}" 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
    if [[ -n "$host_bridge_ip" ]] && ssh -o BatchMode=yes "${username}@${ubuntu_ip}" ping -c1 -W2 "$host_bridge_ip" >/dev/null; then
      record OK 'Ubuntu → HOST' "$host_bridge_ip reachable"
    else
      record KO 'Ubuntu → HOST' 'bridge address unreachable'
    fi

    physical_gateway="$(ip -4 route show default | awk 'NR==1 {print $3}')"
    if [[ -n "$physical_gateway" ]]; then
      if ssh -o BatchMode=yes "${username}@${ubuntu_ip}" ping -c1 -W2 "$physical_gateway" >/dev/null 2>&1; then
        record KO 'Ubuntu → physical LAN' "gateway $physical_gateway unexpectedly reachable"
      else
        record OK 'Ubuntu → physical LAN' "gateway $physical_gateway blocked"
      fi
    else
      record WARN 'Ubuntu → physical LAN' 'no physical default gateway detected'
    fi
  else
    record KO 'HOST → Ubuntu SSH' 'key-based SSH unavailable'
  fi
fi

if [[ -n "$ubuntu_ip" && -n "$windows_ip" ]]; then
  record WARN 'Ubuntu ↔ Windows' "run guest-side test to ${windows_ip}; Windows firewall may block ICMP by policy"
fi

record WARN 'Windows runtime checks' 'inside Windows confirm Internet/DNS, TPM 2.0, Secure Boot and VirtIO devices; Windows firewall makes host-only ping an unreliable proof'
record WARN 'LAN → VM blocked' 'validate from another physical LAN device; NAT/no-forwarding design should prevent inbound access'

printf '\nRuntime certification summary: OK=%d WARN=%d KO=%d\n' "$ok" "$warn" "$ko"
((ko == 0))
