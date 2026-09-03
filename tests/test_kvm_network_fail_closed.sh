#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
guard="$ROOT/scripts/kvm/kvm_network_guard.sh"
unit="$ROOT/virtualization/systemd/fedora-gnome-custom-kvm-guard.service"
dispatcher="$ROOT/virtualization/networkmanager/90-fedora-gnome-custom-kvm-guard"
runtime="$ROOT/scripts/kvm/runtime_certification.sh"

for file in "$guard" "$unit" "$dispatcher" "$runtime"; do
  [[ -f "$file" ]] || { echo "missing KVM fail-closed file: $file" >&2; exit 1; }
done

# Guard must expose an explicit restrictive state and reconcile through it.
grep -Fq 'emergency_guard()' "$guard"
grep -Fq 'reconcile_guard()' "$guard"
grep -Fq 'emergency_guard ||' "$guard"
grep -Fq 'emergency block VM forwarding' "$guard"
grep -Fq 'emergency block forwarding to VM' "$guard"
grep -Fq 'normal block VM to protected host networks' "$guard"
grep -Fq 'normal block protected host networks to VM' "$guard"
grep -Fq 'blocked_host_ipv4' "$guard"
grep -Fq 'protected_networks=' "$guard"
grep -Fq 'route show table main' "$guard"
grep -Fq '"$prefix" != default' "$guard"
grep -Fq 'guard_mode=' "$guard"
grep -Fq 'default IPv4 uplink' "$guard"
grep -Fq 'emergency forwarding block remains active' "$guard"
grep -Fq 'KVM_BLOCK_ROUTED_HOST_NETWORKS="true"' "$ROOT/config/virtualization.conf"

# Reconcile is the systemd start/reload contract; failed oneshots are retried and sandboxed.
grep -Fq 'ExecStart=/usr/local/libexec/fedora-gnome-custom/kvm-network-guard reconcile' "$unit"
grep -Fq 'ExecReload=/usr/local/libexec/fedora-gnome-custom/kvm-network-guard reconcile' "$unit"
grep -Fq 'Restart=on-failure' "$unit"
grep -Fq 'NoNewPrivileges=yes' "$unit"
grep -Fq 'ProtectSystem=strict' "$unit"
grep -Fq 'CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW' "$unit"

# NetworkManager must synchronously install emergency mode before reload.
grep -Fq "\"\$helper\" emergency" "$dispatcher"
grep -Fq "systemctl reload-or-restart \"\$unit\"" "$dispatcher"
if grep -Fq -- '--no-block' "$dispatcher"; then
  echo 'dispatcher must not reload KVM guard asynchronously' >&2
  exit 1
fi
if grep -Eq 'reload-or-restart.*\|\|[[:space:]]*true' "$dispatcher"; then
  echo 'dispatcher must not hide guard reconciliation failure' >&2
  exit 1
fi

# Runtime certification must prove normal state and rule coverage after reload.
grep -Fq "systemctl reload \"\$guard_unit\"" "$runtime"
grep -Fq 'guard_mode=normal' "$runtime"
grep -Fq 'KVM protected CIDR coverage' "$runtime"
grep -Fq 'normal block VM to protected host networks' "$runtime"
grep -Fq 'normal block protected host networks to VM' "$runtime"
grep -Fq 'host cannot prove gateway' "$runtime"
grep -Fq "ping -c 1 -W 2 \"\$physical_gateway\"" "$runtime"

echo 'KVM network fail-closed contract: PASS'
