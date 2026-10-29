#!/usr/bin/env bash
# Pre-1.0 hardening run for real in a repository copy: runtime identity fails
# closed through a fake systemd-detect-virt, diagnostic.sh routes each runtime,
# the certification fingerprint follows the graphics/runtime package versions,
# KVM IPv6 stays refused and preflight never mutates.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015,SC2163,SC2123
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "pre1 hardening behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/proc" "$tmp/root/run"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME XDG_STATE_HOME

# The WSL and container probes read fixed host paths; point them at the fixture.
sed -i -e 's|/proc/sys/kernel/osrelease /proc/version|"$T_TMP/proc/osrelease" "$T_TMP/proc/version"|' \
  -e 's|-e /.dockerenv \|\| -e /run/.containerenv|-e "$T_TMP/root/.dockerenv" \|\| -e "$T_TMP/root/run/.containerenv"|' "$fixture/lib/common.sh"
grep -Fq '$T_TMP/proc/osrelease' "$fixture/lib/common.sh" && grep -Fq '$T_TMP/root/.dockerenv' "$fixture/lib/common.sh" \
  || fail 'cannot redirect the runtime probes'
echo 6.18.0-fixture > "$tmp/proc/osrelease"; echo 'Linux version 6.18.0-fixture' > "$tmp/proc/version"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
# T_VIRT: none (bare metal), kvm, docker, or ambiguous (systemd-detect-virt cannot tell).
fake systemd-detect-virt 'case "${T_VIRT:-none}:$1" in
  docker:--container) echo docker ;;
  kvm:--vm) echo kvm ;;
  *:--container|*:--vm) echo none; exit 1 ;;
  none:--quiet) exit 1 ;;
  kvm:--quiet|docker:--quiet) exit 0 ;;
  *) exit 2 ;;
esac'
fake rpm 'pkg="${@: -1}"; var="T_RPM_${pkg//-/_}"; [[ -n "${!var:-}" ]] || exit 1; printf "%s" "${!var}"'
export PATH="$tmp/bin:$PATH"
printf '#!/usr/bin/env bash\nprintf "workstation-doctor %%s\\n" "$*" >> "$T_LOG"\n' > "$fixture/diagnostics/workstation-doctor"

detect() { (unset CI GITHUB_ACTIONS GITLAB_CI; export "$@"; source "$fixture/lib/common.sh"; runtime_environment_detect); }
[[ "$(detect T_VIRT=none)" == baremetal ]] || fail "bare metal detected as $(detect T_VIRT=none)"
[[ "$(detect T_VIRT=kvm)" == vm ]] || fail 'VM not detected'
[[ "$(detect T_VIRT=docker)" == container ]] || fail 'container not detected'
[[ "$(detect T_VIRT=ambiguous)" == unknown ]] || fail 'ambiguous virtualization promoted to bare metal'
[[ "$(detect CI=true)" == ci ]] || fail 'CI not detected'
touch "$tmp/root/run/.containerenv"
[[ "$(detect T_VIRT=none)" == container ]] || fail 'Podman container marker ignored'
rm "$tmp/root/run/.containerenv"
echo 6.6.87.2-microsoft-standard-WSL2 > "$tmp/proc/osrelease"
[[ "$(detect T_VIRT=none)" == wsl2 ]] || fail 'WSL2 not detected'
echo 6.18.0-fixture > "$tmp/proc/osrelease"
mkdir -p "$tmp/minbin"; for tool in grep cat; do ln -s "$(command -v "$tool")" "$tmp/minbin/$tool"; done
[[ "$(PATH="$tmp/minbin"; detect T_VIRT=none)" == unknown ]] || fail 'bare metal assumed without systemd-detect-virt'

# diagnostic.sh: certification only on proven bare metal.
diagnostic() { rm -f "$T_LOG"; env -u CI -u GITHUB_ACTIONS -u GITLAB_CI "$@" bash "$fixture/diagnostic.sh" > "$tmp/out" 2>&1; }
diagnostic T_VIRT=none || fail 'bare-metal diagnostic failed'
grep -Fxq 'workstation-doctor --summary' "$T_LOG" || fail 'bare metal did not run the workstation doctor'
for virt in kvm docker; do
  diagnostic T_VIRT="$virt" || fail "$virt diagnostic failed"
  [[ ! -e "$T_LOG" ]] && grep -Fq 'REAL APPLY and hardware certification are blocked' "$tmp/out" || fail "$virt not blocked from certification"
done
diagnostic CI=true && [[ ! -e "$T_LOG" ]] && grep -Fq 'CI RUNTIME DETECTED' "$tmp/out" || fail 'CI not routed to CI evidence'
rc=0; diagnostic T_VIRT=ambiguous || rc=$?
[[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail "ambiguous runtime diagnosed as bare metal (rc=$rc)"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
source "$fixture/config/performance.conf"
log_info() { :; }; log_error() { :; }

# Fingerprint: hardware, kernel, runtime contracts and every listed package version.
baseline_fingerprint() { echo hardware; }
driver_contract_fingerprint() { echo drivers; }
application_runtime_fingerprint() { echo applications; }
kvm_contract_fingerprint() { echo kvm; }
RUNTIME_ENVIRONMENT=baremetal
for pkg in $FINAL_CERT_FINGERPRINT_PACKAGES; do export "T_RPM_${pkg//-/_}=1.0-1.fc45.x86_64"; done
base="$(workstation_runtime_fingerprint)"
[[ "$base" =~ ^[0-9a-f]{64}$ ]] || fail "fingerprint is not a SHA-256: $base"
[[ "$(workstation_runtime_fingerprint)" == "$base" ]] || fail 'fingerprint not deterministic'
for pkg in $FINAL_CERT_FINGERPRINT_PACKAGES; do
  var="T_RPM_${pkg//-/_}"
  changed="$(export "$var=2.0-1.fc45.x86_64"; workstation_runtime_fingerprint)"
  [[ "$changed" != "$base" ]] || fail "fingerprint ignores $pkg updates"
  removed="$(unset "$var"; workstation_runtime_fingerprint)"
  [[ "$removed" != "$base" ]] || fail "fingerprint ignores a missing $pkg"
done
[[ "$(driver_contract_fingerprint() { echo other; }; workstation_runtime_fingerprint)" != "$base" ]] || fail 'fingerprint ignores the driver contract'
[[ "$(ENABLE_KVM=false workstation_runtime_fingerprint)" != "$base" ]] || fail 'fingerprint ignores the KVM contract'
for pkg in mesa-dri-drivers intel-gpu-firmware mutter gnome-shell; do
  [[ " $FINAL_CERT_FINGERPRINT_PACKAGES " == *" $pkg "* ]] || fail "certification fingerprint does not track $pkg"
done

# KVM network: IPv4 only, fail-closed isolation, guard check required.
source "$fixture/config/virtualization.conf"
source "$fixture/modules/virtualization/34_kvm_network.sh"
for command in ip firewall-cmd; do fake "$command" ':'; done
printf '#!/usr/bin/env bash
exit "${T_GUARD_RC:-0}"
' > "$fixture/scripts/kvm/kvm_network_guard.sh"
DRY_RUN=true kvm_network_precheck || fail 'KVM network precheck refused the Golden policy'
for override in KVM_IPV6_ENABLED=true KVM_ALLOW_INBOUND_FORWARDING=true KVM_BLOCK_ROUTED_HOST_NETWORKS=false KVM_BLOCK_PHYSICAL_LAN=false T_GUARD_RC=1; do
  rc=0; (export "$override"; DRY_RUN=true kvm_network_precheck) || rc=$?
  [[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "KVM network accepted $override (rc=$rc)"
done
rc=0; ENABLE_KVM=false KVM_IPV6_ENABLED=true kvm_network_precheck || rc=$?
[[ "$rc" == 0 ]] || fail 'disabled KVM still prechecked'

# Preflight never mutates; APPLY runs the command.
DRY_RUN=true run_mutating TEST touch "$tmp/mutated"
[[ ! -e "$tmp/mutated" ]] || fail 'preflight ran a mutation'
DRY_RUN=false run_mutating TEST touch "$tmp/mutated"
[[ -e "$tmp/mutated" ]] || fail 'APPLY skipped a mutation'

echo 'pre1 hardening behavior: PASS'
