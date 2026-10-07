#!/usr/bin/env bash
# Behavioral test: the KVM fail-closed guard keeps the Tailscale network out of reach of the VMs,
# both from the policy-routing table tailscaled creates and from the static range the remote profile adds.
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
guard="$ROOT/scripts/kvm/kvm_network_guard.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
fail() { echo "remote kvm guard behavior: FAIL: $*" >&2; exit 1; }

# Minimal `ip` stub driven by two files so each scenario controls the host routing state.
cat > "$tmp/bin/ip" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
args="$*"
case "$args" in
  '-4 route show default') echo 'default via 192.168.1.1 dev enp5s0' ;;
  '-4 route show table main') cat "$STUB_DIR/main-routes" ;;
  '-4 rule show') cat "$STUB_DIR/rules" ;;
  '-4 route show table 52') cat "$STUB_DIR/table52" ;;
  *) echo "unexpected ip call: $args" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/ip"
export STUB_DIR="$tmp"
printf '%s\n' 'default via 192.168.1.1 dev enp5s0' '192.168.1.0/24 dev enp5s0 proto kernel scope link' > "$tmp/main-routes"
printf '%s\n' '0:	from all lookup local' '32766:	from all lookup main' '32767:	from all lookup default' > "$tmp/rules"
: > "$tmp/table52"

run_check() { env PATH="$tmp/bin:$PATH" "$@" bash "$guard" check; }

# 1. LAN only: no tailnet range unless the remote profile asks for it.
out="$(run_check)" || fail 'baseline check must pass'
grep -Fq 'protected_networks=192.168.1.0/24' <<<"$out" || fail "baseline protected networks: $out"
grep -Fq '100.64.0.0/10' <<<"$out" && fail 'tailnet range must not be protected without the remote profile'

# 2. The remote profile adds the whole Tailscale range statically.
out="$(run_check KVM_EXTRA_PROTECTED_CIDRS=100.64.0.0/10)" || fail 'extra CIDR check must pass'
grep -Fq '100.64.0.0/10' <<<"$out" || fail "static tailnet range missing: $out"
grep -Fq '192.168.1.0/24' <<<"$out" || fail 'LAN protection lost when extra CIDRs are set'

# 3. tailscaled's policy-routing table is discovered dynamically too.
printf '%s\n' '0:	from all lookup local' '5210:	from all fwmark 0x80000/0xff0000 lookup main' '5270:	from all lookup 52' '32766:	from all lookup main' '32767:	from all lookup default' > "$tmp/rules"
printf '%s\n' '100.100.100.100 dev tailscale0' '100.101.102.103 dev tailscale0' > "$tmp/table52"
out="$(run_check)" || fail 'tailscale-style policy routing must be supported'
grep -Fq '100.100.100.100/32' <<<"$out" || fail "tailscale table routes not protected: $out"
grep -Fq 'policy_tables=52' <<<"$out" || fail "policy table 52 not reported: $out"

# 4. Invalid or overlapping static ranges fail closed.
if run_check KVM_EXTRA_PROTECTED_CIDRS=not-a-cidr >/dev/null 2>&1; then fail 'invalid extra CIDR must be rejected'; fi
if run_check KVM_EXTRA_PROTECTED_CIDRS=192.168.50.0/24 >/dev/null 2>&1; then fail 'extra CIDR overlapping the KVM subnet must be rejected'; fi

echo 'remote kvm guard behavior: PASS'
