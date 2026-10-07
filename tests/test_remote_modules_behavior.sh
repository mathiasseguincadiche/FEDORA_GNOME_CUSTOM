#!/usr/bin/env bash
# Behavioral test of the remote-access modules with simulated system commands:
# disabled profile is a strict no-op; enabled profile issues exactly the intended mutations;
# unsafe configuration or a missing SSH key is refused before any change.
# shellcheck disable=SC1090,SC2034,SC2030,SC2031
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
labdir="$(mktemp -d)"
trap 'rm -rf "$labdir"' EXIT
fail() { echo "remote modules behavior: FAIL: $*" >&2; exit 1; }

# Simulated system commands (PATH stubs).
mkdir -p "$labdir/bin"
for tool in dnf systemctl firewall-cmd nmcli python3-stub; do :; done
cat > "$labdir/bin/sudo" <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB
cat > "$labdir/bin/firewall-cmd" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *--get-default-zone*) echo FedoraWorkstation ;;
  *--get-zones*) echo 'FedoraWorkstation libvirt' ;;
esac
exit 0
STUB
cat > "$labdir/bin/nmcli" <<'STUB'
#!/usr/bin/env bash
case "$*" in *GENERAL.CONNECTION*) echo 'Wired connection 1' ;; esac
exit 0
STUB
cat > "$labdir/bin/dnf" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$labdir/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$labdir/bin/getenforce" <<'STUB'
#!/usr/bin/env bash
echo "${STUB_ENFORCE:-Enforcing}"
STUB
chmod +x "$labdir/bin/"*
export PATH="$labdir/bin:$PATH"

# Fake sysfs with the wired r8169 interface, a fake HOME and a fake KVM guard unit.
sysfs="$labdir/sys"
mkdir -p "$sysfs/class/net/enp5s0/device" "$sysfs/bus/pci/drivers/r8169" "$labdir/home/.ssh"
ln -s "$sysfs/bus/pci/drivers/r8169" "$sysfs/class/net/enp5s0/device/driver"
export REMOTE_SYSFS_ROOT="$sysfs" HOME="$labdir/home" REMOTE_KVM_GUARD_UNIT="$labdir/guard.service"
export REMOTE_STATE_DIR="$labdir/state" REMOTE_GDM_CONF="$labdir/custom.conf"

REPO_ROOT="$ROOT"
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/common.sh"
source "$ROOT/config/remote.conf"
CALLS="$labdir/calls"
log_error() { printf 'ERROR %s\n' "$*" >> "$labdir/log"; }
log_warn() { printf 'WARN %s\n' "$*" >> "$labdir/log"; }
log_info() { printf 'INFO %s\n' "$*" >> "$labdir/log"; }
run_mutating() { shift; printf '%s\n' "$*" >> "$CALLS"; }
install_manifest_packages() { printf 'PKGS %s\n' "$(basename "$2")" >> "$CALLS"; }

# Run one module phase in a subshell; remaining arguments are VAR=value overrides. Prints the return code.
phase() {
  local file="$1" fn="$2"; shift 2
  : > "$CALLS"
  (
    for assignment in "$@"; do export "${assignment?}"; done
    source "$ROOT/modules/remote/$file"
    set +e; "$fn"; echo $?
  )
}
expect_rc() { [[ "$1" == "$2" ]] || fail "$3 (rc=$1, expected $2)"; }
calls_have() { grep -Fq -- "$1" "$CALLS" || fail "expected call missing: $1 --- got: $(tr '\n' ';' < "$CALLS")"; }
calls_lack() { if grep -Fq -- "$1" "$CALLS"; then fail "unexpected call: $1"; fi; }

# 1. Disabled profile: every phase of every module succeeds without a single mutation.
for spec in 70_remote_preflight.sh:remote_preflight 71_remote_network.sh:remote_network 72_remote_ssh.sh:remote_ssh 73_remote_desktop.sh:remote_desktop 79_remote_validation.sh:remote_validation; do
  file="${spec%%:*}"; prefix="${spec##*:}"
  for step in precheck plan apply postcheck; do
    out="$(phase "$file" "${prefix}_${step}" REMOTE_ENABLE=false DRY_RUN=false | tail -n1)"
    expect_rc "$out" 0 "disabled profile: ${prefix}_${step} must succeed"
    [[ ! -s "$CALLS" ]] || fail "disabled profile: ${prefix}_${step} mutated the system: $(cat "$CALLS")"
  done
done

# 2. Enabled, dry-run: network module.
expect_rc "$(phase 71_remote_network.sh remote_network_apply REMOTE_ENABLE=true DRY_RUN=true | tail -n1)" 0 'network apply'
calls_have 'install -m 0644 '"$ROOT"'/config/repos/tailscale.repo /etc/yum.repos.d/tailscale.repo'
calls_have 'PKGS packages-remote-fedora.txt'
calls_have 'PKGS packages-remote-vendor.txt'
calls_have 'systemctl enable --now tailscaled.service'
calls_have 'firewall-cmd --permanent --new-zone=fgc-tailnet'
calls_have 'firewall-cmd --permanent --zone=fgc-tailnet --add-service=ssh'
calls_have 'firewall-cmd --permanent --zone=fgc-tailnet --add-interface=tailscale0'
calls_have '802-3-ethernet.wake-on-lan magic'
calls_have 'nmcli connection up Wired connection 1'
calls_lack '--add-port'
calls_lack 'copr'
calls_lack '80-fgc-wol.link'
calls_lack 'kvm-guard'

# 2b. Sunshine ports only when Sunshine is opted in; never the web UI.
phase 71_remote_network.sh remote_network_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_SUNSHINE_ENABLE=true >/dev/null
calls_have '--zone=fgc-tailnet --add-port=47984/tcp'
calls_have '--zone=fgc-tailnet --add-port=47998/udp'
calls_lack '47990'

# 2c. WoL link fallback and KVM guard drop-in when their preconditions hold.
: > "$labdir/guard.service"
phase 71_remote_network.sh remote_network_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_WOL_LINK_FALLBACK=true >/dev/null
calls_have '80-fgc-wol.link'
calls_have 'kvm-guard.service.d/50-fgc-remote.conf'
calls_have 'systemctl reload-or-restart fedora-gnome-custom-kvm-guard.service'
phase 71_remote_network.sh remote_network_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_WOL_ENABLE=false >/dev/null
calls_lack 'wake-on-lan'
rm -f "$labdir/guard.service"

# 3. SSH module: hardened drop-in, LAN closure only when not opted out.
expect_rc "$(phase 72_remote_ssh.sh remote_ssh_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_SSHD_DROPIN="$labdir/00-fgc-remote.conf" | tail -n1)" 0 'ssh apply'
calls_have "install -Dm0644 "
calls_have '00-fgc-remote.conf'
calls_have 'systemctl enable --now sshd.service'
calls_have 'firewall-cmd --permanent --zone=FedoraWorkstation --remove-service=ssh'
phase 72_remote_ssh.sh remote_ssh_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_SSH_LAN=true REMOTE_SSHD_DROPIN="$labdir/00-fgc-remote.conf" >/dev/null
calls_lack '--remove-service=ssh'

# 4. Desktop module: every step is an explicit opt-in.
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true >/dev/null
[[ ! -s "$CALLS" ]] || fail "desktop module must do nothing without opt-in: $(cat "$CALLS")"
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_SUNSHINE_ENABLE=true >/dev/null
calls_have 'dnf -y copr enable lizardbyte/stable'
calls_have 'PKGS packages-remote-sunshine.txt'
calls_have 'systemctl --user enable sunshine.service'
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_AUTOLOGIN=true >/dev/null
calls_have 'gdm_autologin.py enable --user'
calls_have 'systemctl --user enable fgc-remote-lock.service'
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_AUTOLOGIN=true REMOTE_LOCK_ON_AUTOLOGIN=false >/dev/null
calls_lack 'fgc-remote-lock'
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true REMOTE_POWEROFF_POLKIT=true REMOTE_POLKIT_RULE="$labdir/rule" >/dev/null
calls_have 'install -Dm0644'
calls_have "$labdir/rule"
# Without the marker a hand-made GDM configuration is never touched, even with REMOTE_AUTOLOGIN=false.
printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=someone\n' > "$labdir/custom.conf"
phase 73_remote_desktop.sh remote_desktop_apply REMOTE_ENABLE=true DRY_RUN=true >/dev/null
calls_lack 'gdm_autologin.py disable'

# 5. Preflight refusals, before any change.
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=true | tail -n1)" 0 'valid dry-run preflight'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=true REMOTE_SUNSHINE_TCP_PORTS='47984 99999' | tail -n1)" 20 'invalid port must be refused'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=true REMOTE_SUNSHINE_TCP_PORTS='47984;ls' | tail -n1)" 20 'injected port list must be refused'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=true REMOTE_SUNSHINE_UDP_PORTS='47990' | tail -n1)" 20 'the Sunshine web UI port must be refused'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=false | tail -n1)" 20 'missing SSH public key must be refused'
printf 'not-a-key\n' > "$labdir/home/.ssh/authorized_keys"
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=false | tail -n1)" 20 'a file without a public key must be refused'
printf 'ssh-ed25519 AAAAC3Nza tablet\n' > "$labdir/home/.ssh/authorized_keys"
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=false | tail -n1)" 0 'complete real preflight'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=false STUB_ENFORCE=Permissive | tail -n1)" 20 'SELinux not enforcing must be refused'
expect_rc "$(phase 70_remote_preflight.sh remote_preflight_precheck REMOTE_ENABLE=true DRY_RUN=false REMOTE_SYSFS_ROOT="$labdir/empty-sys" | tail -n1)" 20 'missing wired interface must be refused'

echo 'remote modules behavior: PASS'
