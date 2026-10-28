#!/usr/bin/env bash
# Execute the actual preparation and system modules with an initially empty
# package fixture. No host package manager, sudo or hardware command is run.
# shellcheck disable=SC2034,SC1090,SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "installation prerequisites behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/fixture/diagnostics" "$tmp/fixture/manifests" "$tmp/fixture/lib" "$tmp/installed" "$tmp/reports"
cp "$ROOT/diagnostics/baseline-doctor" "$tmp/fixture/diagnostics/"
cp "$ROOT/lib/persistent_data.sh" "$tmp/fixture/lib/"
cp "$ROOT/manifests/packages-baseline.txt" "$ROOT/manifests/packages-system.txt" "$tmp/fixture/manifests/"
export PREREQ_TEST_ROOT="$ROOT" PREREQ_TEST_TMP="$tmp"
cat > "$tmp/fixture/lib/bootstrap.sh" <<'STUB'
source "$PREREQ_TEST_ROOT/lib/common.sh"
source "$PREREQ_TEST_ROOT/lib/constants.sh"
source "$PREREQ_TEST_ROOT/lib/mutations.sh"
engine_bootstrap() { REPORT_ROOT="$PREREQ_TEST_TMP/reports"; RUN_ID=fixture; }
runtime_is_baremetal() { [[ "${PREREQ_TEST_RUNTIME:-baremetal}" == baremetal ]]; }
runtime_environment() { echo "${PREREQ_TEST_RUNTIME:-baremetal}"; }
fedora_require_selected() { :; }
log_info() { :; }
ui_error() { echo "$*" >&2; }
ui_banner() { :; }
ui_meta() { :; }
ui_check() { :; }
baseline_fingerprint() { echo fixture; }
baseline_fingerprint_payload() { echo fixture; }
hardware_platform_board_vendor() { echo fixture; }
hardware_platform_board_name() { echo fixture; }
hardware_platform_bios_vendor() { echo fixture; }
hardware_platform_bios_version() { echo fixture; }
hardware_platform_bios_date() { echo fixture; }
journalctl() { :; }
baseline_certification_valid() { return 1; }
baseline_evidence_valid() { return 1; }
hardware_platform_wifi_lock_valid() { return 1; }
physical_bluetooth_lock_valid() { return 1; }
physical_cooling_lock_valid() { return 1; }
command_exists() {
  case "$1" in
    smartctl) [[ -e "$PREREQ_TEST_TMP/installed/smartmontools" ]] ;;
    semanage) [[ -e "$PREREQ_TEST_TMP/installed/policycoreutils-python-utils" ]] ;;
    *) return 0 ;;
  esac
}
sudo() {
  printf '%s\n' "$*" >> "$PREREQ_TEST_TMP/calls"
  [[ "$1" == dnf ]] || return 99
  shift
  dnf "$@"
}
dnf() {
  (( ${PREREQ_TEST_DNF_RC:-0} == 0 )) || return "$PREREQ_TEST_DNF_RC"
  [[ "$1" == -y ]] && shift
  case "$1" in
    install)
      shift
      for package in "$@"; do : > "$PREREQ_TEST_TMP/installed/$package"; done
      ;;
    upgrade) ;;
    *) return 99 ;;
  esac
}
STUB

REPO_ROOT="$tmp/fixture"
source "$REPO_ROOT/lib/bootstrap.sh"
! command_exists smartctl || fail 'fixture unexpectedly starts with SMART tools'
bash "$REPO_ROOT/diagnostics/baseline-doctor" prepare-tools
command_exists smartctl || fail 'explicit preparation did not install smartmontools'
for package in pciutils kmod util-linux stress-ng dmidecode fio; do
  [[ -f "$tmp/installed/$package" ]] || fail "pre-enrollment package missing: $package"
done

# Status stays read-only even on a machine without the prerequisite package.
rm -f "$tmp/installed/smartmontools" "$tmp/calls"
bash "$REPO_ROOT/diagnostics/baseline-doctor" status
bash "$REPO_ROOT/diagnostics/baseline-doctor" snapshot
[[ ! -e "$tmp/calls" ]] || fail 'status installed a package'
! command_exists smartctl || fail 'status/snapshot silently prepared SMART tools'
rc=0
PREREQ_TEST_DNF_RC=37 bash "$REPO_ROOT/diagnostics/baseline-doctor" prepare-tools || rc=$?
[[ "$rc" == 37 && ! -e "$tmp/installed/smartmontools" ]] || fail 'package installation failure was hidden'
rm -f "$tmp/calls"
rc=0
PREREQ_TEST_RUNTIME=container bash "$REPO_ROOT/diagnostics/baseline-doctor" prepare-tools >/dev/null 2>&1 || rc=$?
[[ "$rc" == 50 && ! -e "$tmp/calls" ]] || fail 'preparation bypassed the bare-metal runtime requirement'

# The public installation facade reaches the explicit preparation action.
source "$ROOT/lib/control_center.sh"
cc_cli_dispatch install prepare-tools
command_exists smartctl || fail 'Control Center did not prepare baseline tools'

# semanage must be available from system convergence, before any KVM module.
source "$ROOT/modules/system/01_os_updates.sh"
source "$ROOT/modules/desktop/25_persistent_data.sh"
persistent_data_validate_mount() { :; }
persistent_data_layout_paths() { :; }
persistent_data_owner_user() { echo fixture; }
DRY_RUN=false
rc=0; desktop_persistent_data_precheck || rc=$?
[[ "$rc" == 20 ]] || fail 'missing semanage did not expose the prerequisite gap'
system_updates_apply
command_exists semanage || fail 'system convergence did not install the SELinux tools'
desktop_persistent_data_precheck || fail '/data still depends on KVM package installation'

# Render the actual Kickstart heredoc only. This writes text in the fixture;
# neither its disk verification nor its installation instructions execute.
python3 - "$ROOT" "$tmp" <<'PY'
from pathlib import Path
import os
import subprocess
import sys
root, tmp = map(Path, sys.argv[1:])
code = (root / 'installer/lib/generate-kickstart.sh').read_text()
start = code.index('baseline_packages=')
end = code.index('\nEOF_KS', start) + len('\nEOF_KS')
script = tmp / 'render-kickstart.sh'
script.write_text('set -Eeuo pipefail\n' + code[start:end] + '\n')
output = tmp / 'prepared.ks'
values = dict(REPO_ROOT=str(root), output=str(output), repo_sha='0' * 40,
              FEDORA_RELEASE='45', FEDORA_COMPOSE='fixture', ISO_FILENAME='fixture.iso',
              ISO_SHA256='0' * 64, hostname='fixture', username='fixture', hash='fixture',
              disk='/dev/disk/by-id/nvme-FIXTURE', disk_name='disk/by-id/nvme-FIXTURE',
              serial='FIXTURE', release='45')
subprocess.run(['bash', str(script)], env=os.environ | values, check=True)
packages = output.read_text().split('%packages\n', 1)[1].split('%end', 1)[0].splitlines()
for package in ('smartmontools', 'pciutils', 'kmod', 'util-linux', 'stress-ng', 'dmidecode', 'fio'):
    assert package in packages, package
# HOST policy chosen by the owner: no SSH server, SSH client available, no
# disk encryption added behind their back, installation only on the chosen disk.
kickstart = output.read_text().splitlines()
assert 'services --enabled=NetworkManager,firewalld --disabled=sshd' in kickstart, 'sshd not disabled'
assert 'openssh-clients' in packages, 'SSH client missing'
assert not any('luks' in line.lower() or '--encrypted' in line for line in kickstart), 'encryption introduced'
for line in ('bootloader --boot-drive=disk/by-id/nvme-FIXTURE', 'ignoredisk --only-use=disk/by-id/nvme-FIXTURE',
             'clearpart --all --initlabel --drives=disk/by-id/nvme-FIXTURE'):
    assert line in kickstart, f'not bound to the target disk: {line}'
assert any(line.startswith('url --mirrorlist=') for line in kickstart), 'no Fedora package source'
PY
echo 'installation prerequisites behavior: PASS'
