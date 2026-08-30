#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; source "$REPO_ROOT/config/virtualization.conf"; source "$REPO_ROOT/config/hardware-components.conf"; source "$REPO_ROOT/config/vm-profiles.conf"
uri="${LIBVIRT_URI:-qemu:///system}"; ubuntu="${UBUNTU_SERVER_NAME:-ubuntu-devops}"; windows="${WINDOWS11_NAME:-windows-11}"; network="${KVM_NETWORK_NAME:-devops-nat}"; username="${UBUNTU_SERVER_USERNAME:-mathias}"; ok=0; warn=0; ko=0
record(){ printf '%-4s %-30s %s\n' "$1" "$2" "$3"; case "$1" in OK)((ok+=1));; WARN)((warn+=1));; KO)((ko+=1));; esac; }
vsh(){ sudo virsh --connect "$uri" "$@"; }
domain_ip(){ local dom="$1" ip="" mac=""; ip="$(vsh domifaddr "$dom" --source agent 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')"; if [[ -z "$ip" ]]; then mac="$(vsh domiflist "$dom" 2>/dev/null | awk -v net="$network" '$3 == net {print $5; exit}')"; [[ -n "$mac" ]] && ip="$(vsh net-dhcp-leases "$network" 2>/dev/null | awk -v mac="$mac" '$0 ~ mac && $0 ~ /ipv4/ {sub(/\/.*/, "", $5); print $5; exit}')"; fi; printf '%s' "$ip"; }
domain_xml_has(){ vsh dumpxml "$1" 2>/dev/null | grep -Eq "$2"; }
agent_ping(){ vsh qemu-agent-command "$1" '{"execute":"guest-ping"}' >/dev/null 2>&1; }
for dom in "$ubuntu" "$windows"; do if vsh dominfo "$dom" >/dev/null 2>&1; then record OK "domain $dom" present; else record KO "domain $dom" missing; fi; done
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
ubuntu_ip="$(domain_ip "$ubuntu")"; windows_ip="$(domain_ip "$windows")"; [[ -n "$ubuntu_ip" ]] && record OK 'Ubuntu IP' "$ubuntu_ip" || record KO 'Ubuntu IP' unavailable; [[ -n "$windows_ip" ]] && record OK 'Windows IP' "$windows_ip" || record WARN 'Windows IP' unavailable
if [[ -n "$ubuntu_ip" ]] && ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${username}@${ubuntu_ip}" true >/dev/null 2>&1; then record OK 'HOST → Ubuntu SSH' reachable; ssh -o BatchMode=yes "${username}@${ubuntu_ip}" 'sudo /usr/local/sbin/devops-verify.sh' >/dev/null 2>&1 && record OK 'Ubuntu DevOps stack' verified || record KO 'Ubuntu DevOps stack' failed; ssh -o BatchMode=yes "${username}@${ubuntu_ip}" 'getent ahostsv4 example.com >/dev/null && curl -fsS --max-time 10 https://example.com >/dev/null' && record OK 'Ubuntu DNS/Internet' working || record KO 'Ubuntu DNS/Internet' failed; else record KO 'HOST → Ubuntu SSH' unavailable; fi
if "$REPO_ROOT/diagnostics/kvm-io-doctor" --quiet; then record OK 'T705 KVM I/O profile' benchmarked; else record WARN 'T705 KVM I/O profile' 'default profile in use'; fi
record WARN 'Windows guest integration' 'inside Windows, Configure-GuestIntegration.ps1 must report healthy VirtIO devices and QEMU-GA'
printf '\nRuntime certification summary: OK=%d WARN=%d KO=%d\n' "$ok" "$warn" "$ko"; ((ko == 0))
