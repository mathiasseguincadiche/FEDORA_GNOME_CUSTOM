#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config/virtualization.conf
source "$REPO_ROOT/config/virtualization.conf"
# shellcheck source=config/vm-profiles.conf
source "$REPO_ROOT/config/vm-profiles.conf"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

[[ ${EUID:-$(id -u)} -ne 0 ]] || fail 'run this helper as the desktop user, not as root'

uri="${LIBVIRT_URI:-qemu:///system}"
network="${KVM_NETWORK_NAME:-devops-nat}"
ubuntu="${UBUNTU_SERVER_NAME:-ubuntu-devops}"
windows="${WINDOWS11_NAME:-windows-11}"
ubuntu_user="${UBUNTU_SERVER_USERNAME:-mathias}"
ubuntu_label="${UBUNTU_SERVER_NAUTILUS_LABEL:-Ubuntu DevOps}"
windows_label="${WINDOWS11_NAUTILUS_LABEL:-Windows VM}"
windows_share="${WINDOWS11_SMB_SHARE_NAME:-VM-Share}"
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

ensure_bookmark_file() {
  mkdir -p "$(dirname "$bookmark_file")"
  touch "$bookmark_file"
  chmod 0600 "$bookmark_file"
}

upsert_bookmark() {
  local uri_value="$1" label="$2" tmp
  ensure_bookmark_file
  tmp="$(mktemp)"
  awk -v label="$label" 'index($0, " " label) == 0 {print}' "$bookmark_file" >"$tmp"
  printf '%s %s\n' "$uri_value" "$label" >>"$tmp"
  cat "$tmp" >"$bookmark_file"
  rm -f "$tmp"
  printf 'OK: Nautilus bookmark "%s" -> %s\n' "$label" "$uri_value"
}

remove_bookmark_label() {
  local label="$1" tmp
  [[ -f "$bookmark_file" ]] || return 0
  tmp="$(mktemp)"
  awk -v label="$label" 'index($0, " " label) == 0 {print}' "$bookmark_file" >"$tmp"
  cat "$tmp" >"$bookmark_file"
  rm -f "$tmp"
}

install_bookmarks() {
  local ubuntu_ip windows_ip
  ubuntu_ip="$(domain_ip "$ubuntu")"
  windows_ip="$(domain_ip "$windows")"

  if [[ -n "$ubuntu_ip" ]]; then
    upsert_bookmark "sftp://${ubuntu_user}@${ubuntu_ip}/home/${ubuntu_user}" "$ubuntu_label"
  else
    warn "$ubuntu has no discoverable IP yet; start it and rerun this helper"
  fi

  if [[ -n "$windows_ip" ]]; then
    upsert_bookmark "smb://${windows_ip}/${windows_share}" "$windows_label"
  else
    warn "$windows has no discoverable IP yet; finish Windows networking and rerun this helper"
  fi

  printf 'Nautilus bookmarks file: %s\n' "$bookmark_file"
}

open_guest() {
  local dom="$1" scheme="$2" ip target
  command -v gio >/dev/null 2>&1 || fail 'gio is unavailable'
  ip="$(domain_ip "$dom")"
  [[ -n "$ip" ]] || fail "no IP found for $dom"
  case "$scheme" in
    sftp) target="sftp://${ubuntu_user}@${ip}/home/${ubuntu_user}" ;;
    smb) target="smb://${ip}/${windows_share}" ;;
    *) fail "unsupported scheme: $scheme" ;;
  esac
  printf 'Opening %s\n' "$target"
  gio open "$target" >/dev/null 2>&1 &
}

case "${1:-install}" in
  install|refresh) install_bookmarks ;;
  remove)
    remove_bookmark_label "$ubuntu_label"
    remove_bookmark_label "$windows_label"
    printf 'Removed managed VM bookmarks from %s\n' "$bookmark_file"
    ;;
  show)
    if [[ -f "$bookmark_file" ]]; then
      grep -E " (${ubuntu_label}|${windows_label})$" "$bookmark_file" || true
    fi
    ;;
  open-ubuntu) open_guest "$ubuntu" sftp ;;
  open-windows) open_guest "$windows" smb ;;
  *) fail 'usage: configure_nautilus_vm_access.sh [install|refresh|remove|show|open-ubuntu|open-windows]' ;;
esac
