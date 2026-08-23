#!/usr/bin/env bash
set -Eeuo pipefail

kvm_network_source_xml() {
  printf '%s\n' "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
}

kvm_network_validate_xml() {
  local xml="$1"
  grep -Fq "<name>${KVM_NETWORK_NAME:-devops-nat}</name>" <<<"$xml" &&
    grep -Fq "<forward mode='nat'" <<<"$xml" &&
    grep -Fq "<bridge name='${KVM_BRIDGE_NAME:-virbr50}' zone='${KVM_FIREWALLD_ZONE:-libvirt}'" <<<"$xml" &&
    grep -Fq "address='${KVM_GATEWAY:-192.168.50.254}'" <<<"$xml" &&
    grep -Fq "start='${KVM_DHCP_START:-192.168.50.100}' end='${KVM_DHCP_END:-192.168.50.200}'" <<<"$xml" &&
    grep -Fq "<forwarder addr='${KVM_DNS_1:-9.9.9.9}'" <<<"$xml" &&
    grep -Fq "<forwarder addr='${KVM_DNS_2:-1.1.1.1}'" <<<"$xml"
}

kvm_network_validate_existing() {
  local current
  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "${KVM_NETWORK_NAME:-devops-nat}" >/dev/null 2>&1; then
    return 0
  fi
  current="$(sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dumpxml "${KVM_NETWORK_NAME:-devops-nat}")" || return 1
  if ! kvm_network_validate_xml "$current"; then
    log_error KVM 'existing devops-nat conflicts with the versioned network contract; refusing overwrite'
    return 1
  fi
}

kvm_network_precheck() {
  local source_xml
  is_true "${ENABLE_KVM:-true}" || return 0
  if ! command_exists ip || ! command_exists python3 || ! command_exists firewall-cmd; then return "$EXIT_PRECHECK_FAILED"; fi
  source_xml="$(cat "$(kvm_network_source_xml)" 2>/dev/null || true)"
  if [[ -z "$source_xml" ]] || ! kvm_network_validate_xml "$source_xml"; then
    log_error KVM 'versioned devops-nat XML does not match virtualization.conf'
    return "$EXIT_PRECHECK_FAILED"
  fi
  [[ -r "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/virtualization/networkmanager/90-fedora-gnome-custom-kvm-guard" ]] || return "$EXIT_PRECHECK_FAILED"
  if ! bash "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" check >/dev/null; then
    log_error KVM 'physical network isolation precheck failed'
    return "$EXIT_PRECHECK_FAILED"
  fi
  if is_true "${KVM_FAIL_CLOSED:-true}"; then
    is_true "${KVM_BLOCK_PHYSICAL_LAN:-true}" || return "$EXIT_PRECHECK_FAILED"
    if is_true "${KVM_ALLOW_INBOUND_FORWARDING:-false}"; then
      return "$EXIT_PRECHECK_FAILED"
    fi
  fi
  if ! is_true "${DRY_RUN:-true}"; then
    kvm_network_validate_existing || return "$EXIT_PRECHECK_FAILED"
  fi
}

kvm_network_plan() {
  cat <<'EOF'
FEDORA KVM NETWORK CONTRACT:
- devops-nat = 192.168.50.0/24, bridge virbr50, DHCP .100-.200
- libvirt NAT supplies VM->Internet and DNS through Quad9/Cloudflare forwarders
- bridge is explicitly attached to firewalld zone libvirt
- project-owned nftables guard blocks VM<->physical-LAN forwarding only
- HOST<->VM and VM<->VM remain allowed
- no port forwarding from LAN/Internet to guests
- NetworkManager reloads the guard when physical connectivity changes
- existing conflicting libvirt networks are never overwritten automatically
EOF
}

kvm_network_apply() {
  local network="${KVM_NETWORK_NAME:-devops-nat}" xml helper_src helper_dst unit_src unit_dst dispatcher_src dispatcher_dst
  is_true "${ENABLE_KVM:-true}" || return 0
  xml="$(kvm_network_source_xml)"
  helper_src="$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  helper_dst="/usr/local/libexec/fedora-gnome-custom/kvm-network-guard"
  unit_src="$REPO_ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service"
  unit_dst="/etc/systemd/system/fedora-gnome-custom-kvm-guard.service"
  dispatcher_src="$REPO_ROOT/virtualization/networkmanager/90-fedora-gnome-custom-kvm-guard"
  dispatcher_dst="/etc/NetworkManager/dispatcher.d/90-fedora-gnome-custom-kvm-guard"

  if ! is_true "${DRY_RUN:-true}"; then
    kvm_network_validate_existing || return "$EXIT_APPLY_FAILED"
  fi

  run_mutating KVM sudo install -d -m 0755 /usr/local/libexec/fedora-gnome-custom /etc/NetworkManager/dispatcher.d || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -m 0755 "$helper_src" "$helper_dst" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -m 0644 "$unit_src" "$unit_dst" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -m 0755 "$dispatcher_src" "$dispatcher_dst" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo systemctl daemon-reload || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo systemctl enable --now fedora-gnome-custom-kvm-guard.service || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-define "$xml" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-start "$network" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-autostart "$network" || return "$EXIT_APPLY_FAILED"
    return 0
  fi

  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" >/dev/null 2>&1; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-define "$xml" || return "$EXIT_APPLY_FAILED"
  fi
  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" | grep -Eq '^Active:[[:space:]]+yes'; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-start "$network" || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${KVM_NETWORK_AUTOSTART:-true}"; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-autostart "$network" || return "$EXIT_APPLY_FAILED"
  fi
}

kvm_network_postcheck() {
  local network="${KVM_NETWORK_NAME:-devops-nat}" current zone
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0

  sudo systemctl is-active --quiet fedora-gnome-custom-kvm-guard.service || return "$EXIT_POSTCHECK_FAILED"
  sudo nft list table inet "${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" | grep -Eq '^Active:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" | grep -Eq '^Autostart:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  current="$(sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dumpxml "$network")" || return "$EXIT_POSTCHECK_FAILED"
  kvm_network_validate_xml "$current" || return "$EXIT_POSTCHECK_FAILED"
  zone="$(firewall-cmd --get-zone-of-interface="${KVM_BRIDGE_NAME:-virbr50}" 2>/dev/null || true)"
  [[ "$zone" == "${KVM_FIREWALLD_ZONE:-libvirt}" ]] || {
    log_error KVM "${KVM_BRIDGE_NAME:-virbr50} is not in firewalld zone ${KVM_FIREWALLD_ZONE:-libvirt}"
    return "$EXIT_POSTCHECK_FAILED"
  }
}
