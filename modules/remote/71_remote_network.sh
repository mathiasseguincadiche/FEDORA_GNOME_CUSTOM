#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/remote_access.sh"

remote_network_precheck() {
  remote_enabled || return 0
  command_exists dnf || { log_error REMOTE 'dnf is required'; return "$EXIT_PRECHECK_FAILED"; }
  local file
  for file in config/repos/tailscale.repo manifests/packages-remote-fedora.txt manifests/packages-remote-vendor.txt; do
    [[ -r "$REPO_ROOT/$file" ]] || { log_error REMOTE "missing $file"; return "$EXIT_PRECHECK_FAILED"; }
  done
}

remote_network_plan() {
  if remote_enabled; then
    echo 'Install Tailscale from its signed vendor repository, create the firewalld zone for the tailnet interface, protect the tailnet range from the KVM guest network and enable Wake-on-LAN (magic packet) in the wired NetworkManager profile. The first tailscale login stays manual. Nothing is exposed to the Internet.'
  else
    echo 'Remote-access profile disabled: Tailscale, firewalld zone and Wake-on-LAN untouched.'
  fi
}

remote_network_firewall() {
  local zone="${REMOTE_TAILSCALE_ZONE:-fgc-tailnet}" iface="${REMOTE_TAILSCALE_INTERFACE:-tailscale0}"
  local lan_zone rule family state previous next desired proto port entry
  zone="${zone}"
  lan_zone="$(remote_lan_zone || true)"
  lan_zone="${lan_zone:-FedoraWorkstation}"
  if is_true "${DRY_RUN:-true}" || ! remote_zone_exists "$zone"; then
    run_mutating REMOTE sudo firewall-cmd --permanent --new-zone="$zone" || return "$EXIT_APPLY_FAILED"
  fi
  run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --add-service=ssh || return "$EXIT_APPLY_FAILED"

  # FedoraWorkstation may admit TCP 47990 via its broad high-port rule.
  # Priority -100 ensures the deny happens before ordinary zone allows.
  for family in ipv4 ipv6; do
    rule="rule family=\"$family\" priority=\"-100\" port port=\"47990\" protocol=\"tcp\" drop"
    run_mutating REMOTE sudo firewall-cmd --permanent --zone="$lan_zone" --add-rich-rule="$rule" || return "$EXIT_APPLY_FAILED"
    if [[ "$lan_zone" != "$zone" ]]; then
      run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --add-rich-rule="$rule" || return "$EXIT_APPLY_FAILED"
    fi
  done

  # Only remove ports that this project recorded as its own. A user's
  # pre-existing firewalld openings must not be silently deleted.
  state="$(remote_state_dir)/sunshine-ports.managed"
  previous="$(mktemp)" || return "$EXIT_APPLY_FAILED"
  next="$(mktemp)" || { rm -f "$previous"; return "$EXIT_APPLY_FAILED"; }
  if sudo test -f "$state"; then sudo cat "$state" > "$previous" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }; fi
  desired=''
  if remote_sunshine_enabled; then
    for port in ${REMOTE_SUNSHINE_TCP_PORTS:-}; do desired="$desired $zone:$port/tcp"; done
    for port in ${REMOTE_SUNSHINE_UDP_PORTS:-}; do desired="$desired $zone:$port/udp"; done
  fi
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    if [[ " $desired " == *" $entry "* ]]; then
      printf '%s\n' "$entry" >> "$next"
    else
      proto="${entry#*:}"
      port="${entry%%:*}"
      # A corrupt state file is never fed back into privileged commands.
      if [[ "$port" != "$zone" || ! "$proto" =~ ^[1-9][0-9]{0,4}/(tcp|udp)$ ]]; then
        log_error REMOTE "invalid managed firewall marker entry: $entry"
        rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"
      fi
      run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --remove-port="$proto" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
    fi
  done < "$previous"
  for entry in $desired; do
    if grep -Fxq "$entry" "$next"; then continue; fi
    proto="${entry#*:}"
    if is_true "${DRY_RUN:-true}" || ! sudo firewall-cmd --permanent --zone="$zone" --query-port="$proto" >/dev/null 2>&1; then
      run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --add-port="$proto" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
      printf '%s\n' "$entry" >> "$next"
    fi
  done
  run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --add-interface="$iface" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
  run_mutating REMOTE sudo firewall-cmd --reload || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
  if [[ -s "$next" ]]; then
    run_mutating REMOTE sudo install -Dm0600 "$next" "$state" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
  elif sudo test -e "$state"; then
    run_mutating REMOTE sudo rm -f "$state" || { rm -f "$previous" "$next"; return "$EXIT_APPLY_FAILED"; }
  fi
  rm -f "$previous" "$next"
}

# tailscaled adds its routes after NetworkManager events: the tailnet range is protected statically.
remote_network_kvm_guard() {
  local unit tmp
  unit="$(remote_kvm_guard_unit)"
  if [[ ! -f "$unit" ]]; then
    log_warn REMOTE 'KVM guard not installed: tailnet range protection will be added when the KVM profile is applied'
    return 0
  fi
  tmp="$(mktemp)" || return "$EXIT_APPLY_FAILED"
  printf '[Service]\nEnvironment=KVM_EXTRA_PROTECTED_CIDRS=%s\n' "${REMOTE_TAILNET_CIDR:-100.64.0.0/10}" > "$tmp"
  run_mutating REMOTE sudo install -Dm0644 "$tmp" "$(remote_kvm_guard_dropin)" || { rm -f "$tmp"; return "$EXIT_APPLY_FAILED"; }
  rm -f "$tmp"
  run_mutating REMOTE sudo systemctl daemon-reload || return "$EXIT_APPLY_FAILED"
  run_mutating REMOTE sudo systemctl reload-or-restart fedora-gnome-custom-kvm-guard.service || return "$EXIT_APPLY_FAILED"
}

remote_network_wol() {
  remote_wol_enabled || return 0
  local iface con
  iface="$(remote_wired_interface || true)"
  if [[ -z "$iface" ]]; then
    is_true "${DRY_RUN:-true}" && { log_info REMOTE 'wired interface not detected in dry-run: Wake-on-LAN step skipped'; return 0; }
    log_error REMOTE "no wired interface bound to ${HARDWARE_LAN_DRIVER:-r8169}"; return "$EXIT_APPLY_FAILED"
  fi
  con="$(remote_wired_connection "$iface")"
  if [[ -z "$con" ]]; then
    log_error REMOTE "no active NetworkManager connection on $iface"; return "$EXIT_APPLY_FAILED"
  fi
  run_mutating REMOTE sudo nmcli connection modify "$con" 802-3-ethernet.wake-on-lan "${REMOTE_WOL_MODE:-magic}" || return "$EXIT_APPLY_FAILED"
  # Re-activation briefly drops the link: apply this module from the console, not through SSH on this NIC.
  run_mutating REMOTE sudo nmcli connection up "$con" || return "$EXIT_APPLY_FAILED"
  if is_true "${REMOTE_WOL_LINK_FALLBACK:-false}"; then
    run_mutating REMOTE sudo install -Dm0644 "$REPO_ROOT/remote/systemd/network/80-fgc-wol.link" /etc/systemd/network/80-fgc-wol.link || return "$EXIT_APPLY_FAILED"
  fi
}

remote_network_apply() {
  remote_enabled || return 0
  run_mutating REMOTE sudo install -m 0644 "$REPO_ROOT/config/repos/tailscale.repo" /etc/yum.repos.d/tailscale.repo || return "$EXIT_APPLY_FAILED"
  install_manifest_packages REMOTE "$REPO_ROOT/manifests/packages-remote-fedora.txt" || return "$EXIT_APPLY_FAILED"
  install_manifest_packages REMOTE "$REPO_ROOT/manifests/packages-remote-vendor.txt" || return "$EXIT_APPLY_FAILED"
  run_mutating REMOTE sudo systemctl enable --now tailscaled.service || return "$EXIT_APPLY_FAILED"
  remote_network_firewall || return $?
  remote_network_kvm_guard || return $?
  remote_network_wol || return $?
}

remote_network_postcheck() {
  remote_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0
  local zone="${REMOTE_TAILSCALE_ZONE:-fgc-tailnet}" iface
  rpm -q tailscale >/dev/null 2>&1 || { log_error REMOTE 'tailscale package missing'; return "$EXIT_POSTCHECK_FAILED"; }
  systemctl is-active --quiet tailscaled.service || { log_error REMOTE 'tailscaled is not active'; return "$EXIT_POSTCHECK_FAILED"; }
  remote_zone_exists "$zone" || { log_error REMOTE "firewalld zone $zone missing"; return "$EXIT_POSTCHECK_FAILED"; }
  if remote_wol_enabled; then
    iface="$(remote_wired_interface)" || return "$EXIT_POSTCHECK_FAILED"
    remote_wol_magic_active "$iface" || { log_error REMOTE "Wake-on-LAN is not active on $iface (ethtool must show Wake-on: g)"; return "$EXIT_POSTCHECK_FAILED"; }
  fi
}
