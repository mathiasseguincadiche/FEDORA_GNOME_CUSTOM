#!/usr/bin/env bash
set -Eeuo pipefail

TABLE_FAMILY="inet"
TABLE_NAME="${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}"
BRIDGE_NAME="${KVM_BRIDGE_NAME:-virbr50}"
KVM_CIDR="${KVM_NETWORK_CIDR:-192.168.50.0/24}"

log_error() { printf 'ERROR: %s\n' "$*" >&2; }

default_ipv4_device() {
  ip -4 route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

physical_link_routes() {
  local default_dev route prefix dev
  default_dev="$(default_ipv4_device)"
  while IFS= read -r route; do
    [[ -n "$route" ]] || continue
    prefix="$(awk '{print $1}' <<<"$route")"
    dev="$(awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' <<<"$route")"
    [[ "$prefix" == */* && -n "$dev" ]] || continue
    [[ "$prefix" == "$KVM_CIDR" || "$prefix" == "127.0.0.0/8" ]] && continue
    [[ "$dev" == "$BRIDGE_NAME" ]] && continue

    # Physical NICs expose /sys/class/net/<dev>/device. The default uplink is
    # also accepted so Wi-Fi/VPN-like uplinks without that symlink remain safe.
    if [[ -e "/sys/class/net/$dev/device" || "$dev" == "$default_dev" ]]; then
      printf '%s\n' "$prefix"
    fi
  done < <(ip -4 route show scope link 2>/dev/null)
}

discover_physical_ipv4() {
  physical_link_routes | sort -u
}

validate_networks() {
  local -a local_cidrs=("$@")
  python3 - "$KVM_CIDR" "${local_cidrs[@]}" <<'PY'
import ipaddress
import sys

kvm = ipaddress.ip_network(sys.argv[1], strict=False)
for value in sys.argv[2:]:
    network = ipaddress.ip_network(value, strict=False)
    if network.version != 4:
        raise SystemExit(1)
    if kvm.overlaps(network):
        print(
            f"ERROR: KVM subnet {kvm} overlaps host uplink network {network}",
            file=sys.stderr,
        )
        raise SystemExit(10)
PY
}

append_delete_if_present() {
  local file="$1"
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    printf 'delete table %s %s\n' "$TABLE_FAMILY" "$TABLE_NAME" >>"$file"
  fi
}

apply_table_file() {
  local file="$1"
  nft -c -f "$file" || return 1
  nft -f "$file"
}

remove_table() {
  command -v nft >/dev/null 2>&1 || return 1
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    nft delete table "$TABLE_FAMILY" "$TABLE_NAME"
  fi
}

current_guard_mode() {
  local rules
  if ! command -v nft >/dev/null 2>&1; then
    printf '%s' unavailable
    return 0
  fi
  if ! rules="$(nft list table "$TABLE_FAMILY" "$TABLE_NAME" 2>/dev/null)"; then
    printf '%s' unreadable-or-missing
    return 0
  fi
  if grep -Fq 'fedora-gnome-custom emergency block VM forwarding' <<<"$rules"; then
    printf '%s' emergency
  elif grep -Fq 'fedora-gnome-custom normal block VM to physical LAN' <<<"$rules"; then
    printf '%s' normal
  else
    printf '%s' unknown
  fi
}

check_guard() {
  local routes default_dev
  local -a local_cidrs=()

  command -v ip >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  routes="$(discover_physical_ipv4)" || return 1
  if [[ -n "$routes" ]]; then
    mapfile -t local_cidrs <<<"$routes"
  fi
  validate_networks "${local_cidrs[@]}" || return 1

  default_dev="$(default_ipv4_device)"
  if [[ -n "$default_dev" && ${#local_cidrs[@]} -eq 0 ]]; then
    log_error "default IPv4 uplink $default_dev exists but no directly connected uplink network was discovered"
    return 1
  fi

  printf 'kvm_cidr=%s\n' "$KVM_CIDR"
  printf 'default_uplink=%s\n' "${default_dev:-none}"
  if ((${#local_cidrs[@]} == 0)); then
    printf '%s\n' 'physical_networks=none-connected'
  else
    printf 'physical_networks=%s\n' "$(IFS=,; echo "${local_cidrs[*]}")"
  fi
  printf 'guard_mode=%s\n' "$(current_guard_mode)"
}

emergency_guard() {
  local tmp
  command -v nft >/dev/null 2>&1 || return 1

  tmp="$(mktemp)" || return 1
  trap 'rm -f "$tmp"' RETURN
  append_delete_if_present "$tmp"
  {
    printf 'table inet %s {\n' "$TABLE_NAME"
    printf '  chain forward_guard {\n'
    printf '    type filter hook forward priority -100; policy accept;\n'
    printf '    iifname "%s" counter drop comment "fedora-gnome-custom emergency block VM forwarding"\n' "$BRIDGE_NAME"
    printf '    oifname "%s" counter drop comment "fedora-gnome-custom emergency block forwarding to VM"\n' "$BRIDGE_NAME"
    printf '  }\n'
    printf '}\n'
  } >>"$tmp"

  apply_table_file "$tmp"
}

apply_normal_guard() {
  local routes default_dev tmp first cidr
  local -a local_cidrs=()

  command -v nft >/dev/null 2>&1 || return 1
  command -v ip >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  routes="$(discover_physical_ipv4)" || return 1
  if [[ -n "$routes" ]]; then
    mapfile -t local_cidrs <<<"$routes"
  fi
  validate_networks "${local_cidrs[@]}" || return 1

  default_dev="$(default_ipv4_device)"
  if [[ -n "$default_dev" && ${#local_cidrs[@]} -eq 0 ]]; then
    log_error "refusing normal mode: default IPv4 uplink $default_dev has no discovered directly connected network"
    return 1
  fi

  tmp="$(mktemp)" || return 1
  trap 'rm -f "$tmp"' RETURN
  append_delete_if_present "$tmp"
  {
    printf 'table inet %s {\n' "$TABLE_NAME"
    printf '  set blocked_physical_ipv4 {\n'
    printf '    type ipv4_addr\n'
    printf '    flags interval\n'
    if ((${#local_cidrs[@]} > 0)); then
      printf '    elements = { '
      first=true
      for cidr in "${local_cidrs[@]}"; do
        if [[ "$first" == true ]]; then first=false; else printf ', '; fi
        printf '%s' "$cidr"
      done
      printf ' }\n'
    fi
    printf '  }\n'
    printf '  chain forward_guard {\n'
    printf '    type filter hook forward priority -100; policy accept;\n'
    printf '    iifname "%s" ip daddr @blocked_physical_ipv4 counter reject with icmp type admin-prohibited comment "fedora-gnome-custom normal block VM to physical LAN"\n' "$BRIDGE_NAME"
    printf '    oifname "%s" ip saddr @blocked_physical_ipv4 counter drop comment "fedora-gnome-custom normal block physical LAN to VM"\n' "$BRIDGE_NAME"
    printf '  }\n'
    printf '}\n'
  } >>"$tmp"

  apply_table_file "$tmp"
}

reconcile_guard() {
  # Enter the restrictive state first. If discovery, validation or the normal
  # nftables transaction fails afterwards, this emergency table remains active.
  emergency_guard || {
    log_error 'unable to install emergency KVM forwarding block'
    return 1
  }

  if apply_normal_guard; then
    return 0
  fi

  log_error 'normal KVM LAN isolation could not be rebuilt; emergency forwarding block remains active'
  return 1
}

case "${1:-reconcile}" in
  check) check_guard ;;
  emergency) emergency_guard ;;
  reconcile|apply|reload) reconcile_guard ;;
  remove) remove_table ;;
  *) printf 'Usage: %s [check|emergency|reconcile|apply|reload|remove]\n' "$0" >&2; exit 2 ;;
esac
