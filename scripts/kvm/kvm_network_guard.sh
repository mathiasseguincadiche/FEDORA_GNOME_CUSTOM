#!/usr/bin/env bash
set -Eeuo pipefail

TABLE_FAMILY="inet"
TABLE_NAME="${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}"
BRIDGE_NAME="${KVM_BRIDGE_NAME:-virbr50}"
KVM_CIDR="${KVM_NETWORK_CIDR:-192.168.50.0/24}"

physical_link_routes() {
  local default_dev route prefix dev
  default_dev="$(ip -4 route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
  while IFS= read -r route; do
    [[ -n "$route" ]] || continue
    prefix="$(awk '{print $1}' <<<"$route")"
    dev="$(awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' <<<"$route")"
    [[ "$prefix" == */* && -n "$dev" ]] || continue
    [[ "$prefix" == "$KVM_CIDR" || "$prefix" == "127.0.0.0/8" ]] && continue
    [[ "$dev" == "$BRIDGE_NAME" ]] && continue
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
        print(f'ERROR: KVM subnet {kvm} overlaps physical host network {network}', file=sys.stderr)
        raise SystemExit(10)
PY
}

remove_table() {
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    nft delete table "$TABLE_FAMILY" "$TABLE_NAME"
  fi
}

check_guard() {
  command -v ip >/dev/null
  command -v python3 >/dev/null
  mapfile -t local_cidrs < <(discover_physical_ipv4)
  validate_networks "${local_cidrs[@]}"
  printf 'kvm_cidr=%s\n' "$KVM_CIDR"
  if ((${#local_cidrs[@]} == 0)); then
    printf '%s\n' 'physical_networks=none-connected'
  else
    printf 'physical_networks=%s\n' "$(IFS=,; echo "${local_cidrs[*]}")"
  fi
}

apply_guard() {
  local tmp first cidr
  command -v nft >/dev/null
  command -v ip >/dev/null
  command -v python3 >/dev/null

  mapfile -t local_cidrs < <(discover_physical_ipv4)
  validate_networks "${local_cidrs[@]}"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    printf 'delete table %s %s\n' "$TABLE_FAMILY" "$TABLE_NAME" >> "$tmp"
  fi

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
    printf '    iifname "%s" ip daddr @blocked_physical_ipv4 reject with icmp type admin-prohibited comment "fedora-gnome-custom block VM to physical LAN"\n' "$BRIDGE_NAME"
    printf '    oifname "%s" ip saddr @blocked_physical_ipv4 drop comment "fedora-gnome-custom block physical LAN to VM"\n' "$BRIDGE_NAME"
    printf '  }\n'
    printf '}\n'
  } >> "$tmp"

  nft -c -f "$tmp"
  nft -f "$tmp"
}

case "${1:-apply}" in
  check) check_guard ;;
  apply|reload) apply_guard ;;
  remove) remove_table ;;
  *) printf 'Usage: %s [check|apply|reload|remove]\n' "$0" >&2; exit 2 ;;
esac
