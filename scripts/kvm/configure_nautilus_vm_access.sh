#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_load_libraries
config_load

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

[[ ${EUID:-$(id -u)} -ne 0 ]] || fail 'run this helper as the desktop user, not as root'

uri="${LIBVIRT_URI:-qemu:///system}"
network="${KVM_NETWORK_NAME:-devops-nat}"
rocky="${ROCKY_SERVER_NAME:-rocky-devops}"
rocky_user="${ROCKY_SERVER_USERNAME:-mathias}"
rocky_label="${ROCKY_SERVER_NAUTILUS_LABEL:-Rocky DevOps}"
config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
bookmark_file="${config_home}/gtk-3.0/bookmarks"

guest_virsh() {
  if virsh --connect "$uri" list --all >/dev/null 2>&1; then
    virsh --connect "$uri" "$@"
  elif sudo -n virsh --connect "$uri" list --all >/dev/null 2>&1; then
    sudo -n virsh --connect "$uri" "$@"
  else
    return 1
  fi
}

domain_ip() {
  local dom="$1" ip="" mac=""
  ip="$(guest_virsh domifaddr "$dom" --source agent 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}' || true)"
  if [[ -z "$ip" ]]; then
    mac="$(guest_virsh domiflist "$dom" 2>/dev/null | awk -v net="$network" '$3 == net {print $5; exit}' || true)"
    if [[ -n "$mac" ]]; then
      ip="$(guest_virsh net-dhcp-leases "$network" 2>/dev/null | awk -v mac="$mac" '$0 ~ mac && $0 ~ /ipv4/ {sub(/\/.*/, "", $5); print $5; exit}' || true)"
    fi
  fi
  printf '%s' "$ip"
}

# A GTK bookmark line is "URI [LABEL]": only lines whose label is exactly ours
# are replaced or removed, never a user bookmark that merely contains it.
without_label() {
  awk -v label="$1" '{ uri_end = index($0, " "); if (uri_end > 0 && substr($0, uri_end + 1) == label) next; print }'
}

ensure_bookmark_file() {
  mkdir -p "$(dirname "$bookmark_file")"
  touch "$bookmark_file"
  chmod 0600 "$bookmark_file"
}

upsert_bookmark() {
  local uri_value="$1" label="$2" tmp
  ensure_bookmark_file
  tmp="$(mktemp)"
  without_label "$label" <"$bookmark_file" >"$tmp"
  printf '%s %s\n' "$uri_value" "$label" >>"$tmp"
  cat "$tmp" >"$bookmark_file"
  rm -f "$tmp"
  printf 'OK: Nautilus bookmark "%s" -> %s\n' "$label" "$uri_value"
}

remove_bookmark_label() {
  local label="$1" tmp
  [[ -f "$bookmark_file" ]] || return 0
  tmp="$(mktemp)"
  without_label "$label" <"$bookmark_file" >"$tmp"
  cat "$tmp" >"$bookmark_file"
  rm -f "$tmp"
}

install_bookmarks() {
  local rocky_ip
  rocky_ip="$(domain_ip "$rocky")"

  if [[ -n "$rocky_ip" ]]; then
    upsert_bookmark "sftp://${rocky_user}@${rocky_ip}/home/${rocky_user}" "$rocky_label"
  else
    warn "$rocky has no discoverable IP yet; start it and rerun this helper"
  fi

  printf 'Nautilus bookmarks file: %s\n' "$bookmark_file"
}

open_rocky() {
  local ip target
  command -v gio >/dev/null 2>&1 || fail 'gio is unavailable'
  ip="$(domain_ip "$rocky")"
  [[ -n "$ip" ]] || fail "no IP found for $rocky"
  target="sftp://${rocky_user}@${ip}/home/${rocky_user}"
  printf 'Opening %s\n' "$target"
  gio open "$target" >/dev/null 2>&1 &
}

case "${1:-install}" in
  install|refresh) install_bookmarks ;;
  remove)
    remove_bookmark_label "$rocky_label"
    printf 'Removed managed VM bookmarks from %s\n' "$bookmark_file"
    ;;
  show)
    if [[ -f "$bookmark_file" ]]; then
      awk -v label="$rocky_label" '{ uri_end = index($0, " "); if (uri_end > 0 && substr($0, uri_end + 1) == label) print }' "$bookmark_file"
    fi
    ;;
  open-rocky) open_rocky ;;
  *) fail 'usage: configure_nautilus_vm_access.sh [install|refresh|remove|show|open-rocky]' ;;
esac
