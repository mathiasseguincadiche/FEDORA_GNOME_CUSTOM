#!/usr/bin/env bash
# Static contract of the optional remote-access profile (ADR 0017): safe defaults, no exposure,
# hardened SSH, catalog wiring and documentation. Behaviour is covered by the other test_remote_* tests.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail() { echo "remote access contract: FAIL: $*" >&2; exit 1; }

for file in \
  config/remote.conf config/repos/tailscale.repo \
  manifests/packages-remote-fedora.txt manifests/packages-remote-vendor.txt manifests/packages-remote-sunshine.txt \
  lib/remote_access.sh diagnostics/remote-doctor \
  modules/remote/70_remote_preflight.sh modules/remote/71_remote_network.sh modules/remote/72_remote_ssh.sh modules/remote/73_remote_desktop.sh modules/remote/79_remote_validation.sh \
  remote/ssh/00-fgc-remote.conf.in remote/polkit/50-fgc-remote-power.rules.in remote/systemd/network/80-fgc-wol.link remote/systemd/user/fgc-remote-lock.service \
  scripts/remote/wol-send.py scripts/remote/gdm_autologin.py \
  docs/REMOTE_ACCESS.md docs/adr/0017-remote-access.md; do
  [[ -s "$file" ]] || fail "missing $file"
done
for exe in diagnostics/remote-doctor scripts/remote/wol-send.py scripts/remote/gdm_autologin.py; do
  [[ -x "$exe" ]] || fail "$exe must be executable"
done

# Catalog wiring, in dependency order, after the last existing profile.
grep -Fxq 'remote.preflight|REMOTE|backup.daily|modules/remote/70_remote_preflight.sh' manifests/module-plan.conf || fail 'remote.preflight missing from the module plan'
grep -Fxq 'remote.network|REMOTE|remote.preflight|modules/remote/71_remote_network.sh' manifests/module-plan.conf || fail 'remote.network missing'
grep -Fxq 'remote.ssh|REMOTE|remote.network|modules/remote/72_remote_ssh.sh' manifests/module-plan.conf || fail 'remote.ssh missing'
grep -Fxq 'remote.desktop|REMOTE|remote.ssh|modules/remote/73_remote_desktop.sh' manifests/module-plan.conf || fail 'remote.desktop missing'
grep -Fxq 'remote.validation|REMOTE|remote.desktop|modules/remote/79_remote_validation.sh' manifests/module-plan.conf || fail 'remote.validation missing'

# Safe defaults: nothing is enabled without an explicit owner decision.
for pin in 'REMOTE_ENABLE="false"' 'REMOTE_SSH_LAN="false"' 'REMOTE_WOL_MODE="magic"' 'REMOTE_WOL_LINK_FALLBACK="false"' \
  'REMOTE_SUNSHINE_ENABLE="false"' 'REMOTE_AUTOLOGIN="false"' 'REMOTE_LOCK_ON_AUTOLOGIN="true"' 'REMOTE_POWEROFF_POLKIT="false"' \
  'REMOTE_TAILNET_CIDR="100.64.0.0/10"'; do
  grep -Fxq "$pin" config/remote.conf || fail "config/remote.conf must contain $pin"
done
# The Sunshine web UI is administration: it must never appear in an opened port list.
if grep -E '^REMOTE_SUNSHINE_(TCP|UDP)_PORTS=.*47990' config/remote.conf; then fail 'port 47990 must never be configured'; fi
grep -Fq '47990' modules/remote/70_remote_preflight.sh || fail 'preflight must refuse port 47990'

# Modules are inert when the profile is disabled.
for module in modules/remote/7[0-3]_*.sh modules/remote/79_remote_validation.sh; do
  grep -Fq 'remote_enabled' "$module" || fail "$module must gate on remote_enabled"
done
grep -Fq 'REMOTE_ENABLE:-false' lib/remote_access.sh || fail 'REMOTE_ENABLE must default to disabled when unset'

# SSH hardening template.
for line in 'PermitRootLogin no' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PubkeyAuthentication yes' 'AuthenticationMethods publickey' 'AllowUsers @USER@'; do
  grep -Fxq "$line" remote/ssh/00-fgc-remote.conf.in || fail "SSH template missing: $line"
done
grep -Fq 'sshd -t' modules/remote/72_remote_ssh.sh || fail 'sshd -t validation missing'
grep -Fq 'authorized_keys' modules/remote/70_remote_preflight.sh || fail 'preflight must require an SSH public key'

# Supply chain: signed repository metadata, no pipe-to-shell, no secret in the profile.
grep -Fxq 'repo_gpgcheck=1' config/repos/tailscale.repo || fail 'tailscale repository metadata must be signature-checked'
grep -Fxq 'gpgcheck=1' config/repos/tailscale.repo || fail 'tailscale RPM packages must be signature-checked'
if grep -REn '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' modules/remote lib/remote_access.sh scripts/remote remote; then fail 'no pipe-to-shell in the remote profile'; fi
if grep -REni 'authkey|tskey-|password=|passphrase' modules/remote lib/remote_access.sh scripts/remote remote config/remote.conf; then fail 'no secret or auth key may live in the repository'; fi

# Wake-on-LAN and KVM isolation wiring.
grep -Fq '802-3-ethernet.wake-on-lan' modules/remote/71_remote_network.sh || fail 'Wake-on-LAN must be stored in the NetworkManager profile'
grep -Fq 'KVM_EXTRA_PROTECTED_CIDRS' modules/remote/71_remote_network.sh || fail 'remote profile must protect the tailnet from the KVM guard'
grep -Fq 'KVM_EXTRA_PROTECTED_CIDRS' scripts/kvm/kvm_network_guard.sh || fail 'KVM guard must support extra protected networks'
grep -Fxq 'Environment=KVM_EXTRA_PROTECTED_CIDRS=' virtualization/systemd/fedora-gnome-custom-kvm-guard.service || fail 'KVM guard unit must declare the extra-CIDR variable'
grep -Fxq 'WakeOnLan=magic' remote/systemd/network/80-fgc-wol.link || fail 'WoL link fallback must request magic packets'

# Operator entry points and CI.
grep -Fq 'remote-doctor' control.sh || fail 'control.sh must route remote'
grep -Fq 'manifests/packages-remote-fedora.txt' .github/workflows/fedora-package-preflight.yml || fail 'CI preflight must resolve the Fedora remote manifest'

# Documentation: guide, ADR, indexes, and the honest limits.
for token in 'Verdict sur l'"'"'architecture' 'relais' 'Gate 3' 'expiration' 'FedoraWorkstation' 'GNOME Remote Desktop' 'Non vérifié'; do
  grep -Fq "$token" docs/REMOTE_ACCESS.md || fail "REMOTE_ACCESS.md missing: $token"
done
grep -Fq '0017-remote-access.md' docs/adr/README.md || fail 'ADR index missing 0017'
grep -Fq 'REMOTE_ACCESS.md' docs/README.md || fail 'docs portal must link REMOTE_ACCESS.md'
grep -Fq 'REMOTE_ACCESS.md' README.md || fail 'README must link REMOTE_ACCESS.md'
grep -Fq 'REMOTE_ENABLE' config/local.conf.example || fail 'local.conf.example must document the opt-in'
[[ "$(tr -d '[:space:]' < VERSION)" =~ ^0\.(2[2-9]|[3-9][0-9])\.[0-9]+$ ]] || fail 'VERSION must be at least 0.22.0 (remote access profile shipped in 0.22.0)'
grep -Fq "v$(tr -d '[:space:]' < VERSION)-rc." .github/release-manifest.env || fail 'release manifest must follow VERSION'

echo 'remote access contract: PASS'
