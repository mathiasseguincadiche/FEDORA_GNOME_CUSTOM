#!/usr/bin/env bash
# Aides partagées du profil optionnel « accès distant » (ADR 0017).
# REPO_ROOT est injecté par les points d'entrée avant le chargement de cette bibliothèque.
# shellcheck disable=SC2153

remote_enabled() { is_true "${REMOTE_ENABLE:-false}"; }
remote_wol_enabled() { remote_enabled && is_true "${REMOTE_WOL_ENABLE:-true}"; }
remote_sunshine_enabled() { remote_enabled && is_true "${REMOTE_SUNSHINE_ENABLE:-false}"; }
remote_autologin_enabled() { remote_enabled && is_true "${REMOTE_AUTOLOGIN:-false}"; }
remote_user() { id -un; }
remote_sysfs_root() { printf '%s\n' "${REMOTE_SYSFS_ROOT:-/sys}"; }

remote_state_dir() { printf '%s\n' "${REMOTE_STATE_DIR:-/var/lib/fedora-gnome-custom/remote}"; }
remote_sshd_dropin() { printf '%s\n' "${REMOTE_SSHD_DROPIN:-/etc/ssh/sshd_config.d/00-fgc-remote.conf}"; }
remote_polkit_rule() { printf '%s\n' "${REMOTE_POLKIT_RULE:-/etc/polkit-1/rules.d/50-fgc-remote-power.rules}"; }
remote_kvm_guard_unit() { printf '%s\n' "${REMOTE_KVM_GUARD_UNIT:-/etc/systemd/system/fedora-gnome-custom-kvm-guard.service}"; }
remote_kvm_guard_dropin() { printf '%s\n' "${REMOTE_KVM_GUARD_DROPIN:-/etc/systemd/system/fedora-gnome-custom-kvm-guard.service.d/50-fgc-remote.conf}"; }

# Un numéro de port TCP/UDP valide (1-65535), sans zéro initial ni signe.
remote_valid_port() { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && (( $1 <= 65535 )); }

remote_valid_port_list() {
  local port
  for port in $1; do remote_valid_port "$port" || return 1; done
}

# Interface filaire de la carte mère : celle liée au pilote attendu (r8169 pour le Realtek 5 GbE).
remote_wired_interface() {
  local dev driver want="${HARDWARE_LAN_DRIVER:-r8169}"
  for dev in "$(remote_sysfs_root)"/class/net/*; do
    [[ -L "$dev/device/driver" ]] || continue
    driver="$(basename "$(readlink -f "$dev/device/driver")")"
    if [[ "$driver" == "$want" ]]; then basename "$dev"; return 0; fi
  done
  return 1
}

remote_wired_connection() { nmcli -g GENERAL.CONNECTION device show "$1" 2>/dev/null | head -n1; }

# Affiche « supports=<lettres> current=<lettres> » d'après ethtool (les lettres WoL : g = Magic Packet).
remote_ethtool_wol() {
  local iface="$1" out
  out="$(sudo ethtool "$iface" 2>/dev/null)" || return 1
  awk '/Supports Wake-on:/ {s=$3} /^[[:space:]]*Wake-on:/ {c=$2} END {printf "supports=%s current=%s\n", s, c}' <<<"$out"
}

remote_wol_magic_active() {
  local state
  state="$(remote_ethtool_wol "$1")" || return 1
  [[ "$state" =~ current=[a-z]*g ]]
}

remote_authorized_keys_present() {
  [[ -s "$HOME/.ssh/authorized_keys" ]] && grep -Eq '^(ssh-|ecdsa-|sk-)' "$HOME/.ssh/authorized_keys"
}

remote_tailscale_backend_state() {
  tailscale status --json 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin).get("BackendState", ""))' 2>/dev/null
}

# Applique le nom d'utilisateur dans un modèle (@USER@).
remote_render_template() { sed "s/@USER@/$2/g" "$1"; }

remote_default_zone() { sudo firewall-cmd --get-default-zone 2>/dev/null; }
remote_zone_has_service() { sudo firewall-cmd --permanent --zone="$1" --query-service="$2" >/dev/null 2>&1; }
remote_zone_exists() { sudo firewall-cmd --permanent --get-zones 2>/dev/null | tr ' ' '\n' | grep -Fxq "$1"; }

# Une session GDM est-elle configurée pour s'ouvrir seule ? Sortie : « enabled user=<nom> » ou « disabled ».
remote_autologin_status() { python3 "$REPO_ROOT/scripts/remote/gdm_autologin.py" status --file "${REMOTE_GDM_CONF:-/etc/gdm/custom.conf}"; }

# Capacité d'encodage AV1 matériel exposée par VA-API sur le nœud de rendu donné.
remote_vaapi_av1_encode() {
  local node="$1"
  vainfo --display drm --device "$node" 2>/dev/null | grep -Eq 'VAProfileAV1Profile0.*VAEntrypointEncSlice'
}
