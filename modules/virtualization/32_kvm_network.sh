#!/usr/bin/env bash
set -Eeuo pipefail
kvm_network_precheck() { :; }
kvm_network_plan() { echo 'Create isolated libvirt NAT devops-nat 192.168.50.0/24 only if absent; no physical bridge or host NIC mutation.'; }
kvm_network_apply() {
  is_true "${ENABLE_KVM:-true}" || return 0
  if is_true "${DRY_RUN:-true}"; then log_info KVM 'DRY-RUN: would define devops-nat if absent'; return 0; fi
  sudo virsh net-info "$KVM_NETWORK_NAME" >/dev/null 2>&1 && return 0
  local xml; xml="$(mktemp)"; trap 'rm -f "$xml"' RETURN
  cat > "$xml" <<EOF
<network>
  <name>${KVM_NETWORK_NAME}</name>
  <bridge name='${KVM_BRIDGE_NAME}' stp='on' delay='0'/>
  <forward mode='nat'/>
  <ip address='${KVM_GATEWAY}' netmask='255.255.255.0'>
    <dhcp><range start='${KVM_DHCP_START}' end='${KVM_DHCP_END}'/></dhcp>
  </ip>
</network>
EOF
  sudo virsh net-define "$xml"
  sudo virsh net-autostart "$KVM_NETWORK_NAME"
  sudo virsh net-start "$KVM_NETWORK_NAME"
}
kvm_network_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_KVM:-true}" || return 0; sudo virsh net-info "$KVM_NETWORK_NAME" | grep -Eq 'Active:[[:space:]]+yes'; }
