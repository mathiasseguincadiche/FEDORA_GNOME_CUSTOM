#!/usr/bin/env bash
set -Eeuo pipefail

TABLE_FAMILY="inet"
TABLE_NAME="${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}"
BRIDGE_NAME="${KVM_BRIDGE_NAME:-virbr50}"
KVM_CIDR="${KVM_NETWORK_CIDR:-192.168.50.0/24}"
BLOCK_ROUTED_HOST_NETWORKS="${KVM_BLOCK_ROUTED_HOST_NETWORKS:-true}"

log_error() { printf 'ERROR: %s\n' "$*" >&2; }

default_ipv4_device() {
  ip -4 route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

normalize_route_prefix() {
  local prefix="$1"
  if [[ "$prefix" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    printf '%s/32\n' "$prefix"
  elif [[ "$prefix" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    printf '%s\n' "$prefix"
  else
    return 1
  fi
}

custom_policy_tables() {
  local rules line table
  rules="$(ip -4 rule show 2>/dev/null)" || { log_error 'cannot read IPv4 policy-routing rules'; return 1; }
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    case "$line" in
      '0:'*'lookup local'|'32766:'*'lookup main'|'32767:'*'lookup default') continue ;;
    esac
    table="$(awk '{for(i=1;i<=NF;i++) if($i=="lookup" || $i=="table") {print $(i+1); exit}}' <<<"$line")"
    [[ -n "$table" ]] || { log_error "unsupported custom IPv4 rule without routing table: $line"; return 1; }
    case "$table" in local|main|default) continue ;; esac
    printf '%s\n' "$table"
  done <<<"$rules" | sort -u
}

policy_route_dump() {
  local table tables
  ip -4 route show table main 2>/dev/null || { log_error 'cannot read IPv4 main routing table'; return 1; }
  [[ "$BLOCK_ROUTED_HOST_NETWORKS" == true ]] || return 0
  tables="$(custom_policy_tables)" || return 1
  while IFS= read -r table; do
    [[ -n "$table" ]] || continue
    ip -4 route show table "$table" 2>/dev/null || { log_error "cannot read custom IPv4 routing table: $table"; return 1; }
  done <<<"$tables"
}

protected_host_routes() {
  local route_dump route prefix normalized dev route_type
  route_dump="$(policy_route_dump)" || return 1
  while IFS= read -r route; do
    [[ -n "$route" ]] || continue
    prefix="$(awk '{print $1}' <<<"$route")"
    route_type="$prefix"
    case "$route_type" in default|local|broadcast|unreachable|prohibit|blackhole|throw|nat|multicast) continue ;; esac
    normalized="$(normalize_route_prefix "$prefix" 2>/dev/null || true)"
    [[ -n "$normalized" ]] || continue
    [[ "$normalized" == "$KVM_CIDR" || "$normalized" == 127.0.0.0/8 || "$normalized" == 169.254.0.0/16 ]] && continue
    dev="$(awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' <<<"$route")"
    [[ "$dev" == "$BRIDGE_NAME" ]] && continue

    if [[ "$BLOCK_ROUTED_HOST_NETWORKS" == true ]]; then
      # Protect every explicit non-default route from main and custom policy
      # tables: LAN, VPN, enterprise networks and source-policy destinations.
      printf '%s\n' "$normalized"
    elif [[ -n "$dev" && -e "/sys/class/net/$dev/device" ]]; then
      printf '%s\n' "$normalized"
    fi
  done <<<"$route_dump"
}

discover_protected_ipv4() {
  protected_host_routes | sort -u
}

validate_networks() {
  local -a protected_cidrs=("$@")
  python3 - "$KVM_CIDR" "${protected_cidrs[@]}" <<'PY'
import ipaddress
import sys

kvm = ipaddress.ip_network(sys.argv[1], strict=False)
for value in sys.argv[2:]:
    network = ipaddress.ip_network(value, strict=False)
    if network.version != 4:
        raise SystemExit(1)
    if kvm.overlaps(network):
        print(f"ERROR: KVM subnet {kvm} overlaps protected host network {network}", file=sys.stderr)
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
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then nft delete table "$TABLE_FAMILY" "$TABLE_NAME"; fi
}

current_guard_mode() {
  local rules
  if ! command -v nft >/dev/null 2>&1; then printf '%s' unavailable; return 0; fi
  if ! rules="$(nft list table "$TABLE_FAMILY" "$TABLE_NAME" 2>/dev/null)"; then printf '%s' unreadable-or-missing; return 0; fi
  if grep -Fq 'fedora-gnome-custom emergency block VM forwarding' <<<"$rules"; then
    printf '%s' emergency
  elif grep -Fq 'fedora-gnome-custom normal block VM to protected host networks' <<<"$rules"; then
    printf '%s' normal
  else
    printf '%s' unknown
  fi
}

check_guard() {
  local routes default_dev policy_tables
  local -a protected_cidrs=()
  command -v ip >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  routes="$(discover_protected_ipv4)" || return 1
  [[ -n "$routes" ]] && mapfile -t protected_cidrs <<<"$routes"
  validate_networks "${protected_cidrs[@]}" || return 1
  policy_tables="$(custom_policy_tables)" || return 1

  default_dev="$(default_ipv4_device)"
  if [[ -n "$default_dev" && ${#protected_cidrs[@]} -eq 0 ]]; then
    log_error "default IPv4 uplink $default_dev exists but no protected non-default host network was discovered"
    return 1
  fi

  printf 'kvm_cidr=%s\n' "$KVM_CIDR"
  printf 'default_uplink=%s\n' "${default_dev:-none}"
  printf 'policy_tables=%s\n' "${policy_tables//$'\n'/,}"
  if ((${#protected_cidrs[@]} == 0)); then printf '%s\n' 'protected_networks=none-connected'; else printf 'protected_networks=%s\n' "$(IFS=,; echo "${protected_cidrs[*]}")"; fi
  printf 'guard_mode=%s\n' "$(current_guard_mode)"
}

emergency_guard() {
  local tmp rc=0
  command -v nft >/dev/null 2>&1 || return 1
  tmp="$(mktemp)" || return 1
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
  apply_table_file "$tmp" || rc=$?
  rm -f "$tmp"
  return "$rc"
}

apply_normal_guard() {
  local routes default_dev tmp first cidr rc=0
  local -a protected_cidrs=()
  command -v nft >/dev/null 2>&1 || return 1
  command -v ip >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  routes="$(discover_protected_ipv4)" || return 1
  [[ -n "$routes" ]] && mapfile -t protected_cidrs <<<"$routes"
  validate_networks "${protected_cidrs[@]}" || return 1
  default_dev="$(default_ipv4_device)"
  if [[ -n "$default_dev" && ${#protected_cidrs[@]} -eq 0 ]]; then
    log_error "refusing normal mode: default IPv4 uplink $default_dev has no protected non-default host network"
    return 1
  fi

  tmp="$(mktemp)" || return 1
  append_delete_if_present "$tmp"
  {
    printf 'table inet %s {\n' "$TABLE_NAME"
    printf '  set blocked_host_ipv4 {\n'
    printf '    type ipv4_addr\n'
    printf '    flags interval\n'
    if ((${#protected_cidrs[@]} > 0)); then
      printf '    elements = { '
      first=true
      for cidr in "${protected_cidrs[@]}"; do
        if [[ "$first" == true ]]; then first=false; else printf ', '; fi
        printf '%s' "$cidr"
      done
      printf ' }\n'
    fi
    printf '  }\n'
    printf '  chain forward_guard {\n'
    printf '    type filter hook forward priority -100; policy accept;\n'
    printf '    iifname "%s" ip daddr @blocked_host_ipv4 counter reject with icmp type admin-prohibited comment "fedora-gnome-custom normal block VM to protected host networks"\n' "$BRIDGE_NAME"
    printf '    oifname "%s" ip saddr @blocked_host_ipv4 counter drop comment "fedora-gnome-custom normal block protected host networks to VM"\n' "$BRIDGE_NAME"
    printf '  }\n'
    printf '}\n'
  } >>"$tmp"
  apply_table_file "$tmp" || rc=$?
  rm -f "$tmp"
  return "$rc"
}

reconcile_guard() {
  # Restrict first. Any discovery/policy-routing/validation/nftables failure
  # leaves the emergency table active rather than trusting stale assumptions.
  emergency_guard || { log_error 'unable to install emergency KVM forwarding block'; return 1; }
  if apply_normal_guard; then return 0; fi
  log_error 'normal KVM host-network isolation could not be rebuilt; emergency forwarding block remains active'
  return 1
}

case "${1:-reconcile}" in
  check) check_guard ;;
  emergency) emergency_guard ;;
  reconcile|apply|reload) reconcile_guard ;;
  remove) remove_table ;;
  *) printf 'Usage: %s [check|emergency|reconcile|apply|reload|remove]\n' "$0" >&2; exit 2 ;;
esac
