#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB="$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
DOCTOR="$ROOT/diagnostics/virtualbox-gnome-lab-doctor"

[[ -f "$LAB" ]] || { echo 'VirtualBox GNOME LAB entrypoint missing' >&2; exit 1; }
[[ -f "$DOCTOR" ]] || { echo 'VirtualBox GNOME LAB doctor missing' >&2; exit 1; }
bash -n "$LAB"
bash -n "$DOCTOR"

grep -Fq 'runtime_is_virtualbox()' "$ROOT/lib/common.sh"
grep -Fq '== oracle' "$ROOT/lib/common.sh"
grep -Fq "grep -Eqi 'VirtualBox|Oracle|innotek'" "$ROOT/lib/common.sh"
grep -Fq 'runtime_is_virtualbox' "$LAB"
grep -Fq 'Fedora Linux 44' "$LAB"
grep -Fq 'GNOME Shell 50' "$LAB"
grep -Fq 'Wayland is required for GATE 2' "$LAB"
grep -Fq 'sudo dnf -y install curl unzip xdg-user-dirs glib2' "$LAB"
grep -Fq 'modules/gnome/23_gnome_settings.sh' "$LAB"
grep -Fq 'modules/gnome/24_gnome_extensions.sh' "$LAB"
grep -Fq 'modules/gnome/24b_resource_monitor.sh' "$LAB"
grep -Fq 'scripts/gnome/install-ding.sh' "$LAB"
grep -Fq 'scripts/gnome/install-show-desktop-plus.sh' "$LAB"
grep -Fq 'gnome_telemetry_apply' "$LAB"
grep -Fq "gnome_extension_enable_checked 'Desktop Icons NG'" "$LAB"
grep -Fq "gnome_extension_enable_checked 'Show Desktop Plus'" "$LAB"
grep -Fq 'virtualbox-gnome-lab-doctor' "$LAB"

for forbidden in 'orchestrator_run_all' 'apply_gate_open' 'modules/system/' 'modules/hardware/' 'modules/virtualization/' 'modules/backup/' 'prepare-preapply-backup.sh'; do
  if grep -Fq "$forbidden" "$LAB"; then
    echo "VirtualBox GNOME LAB contains forbidden production path: $forbidden" >&2
    exit 1
  fi
done

for forbidden in 'run_mutating' 'sudo ' 'dnf -y install'; do
  if grep -Fq "$forbidden" "$DOCTOR"; then
    echo "VirtualBox GNOME LAB doctor must stay read-only: $forbidden" >&2
    exit 1
  fi
done

grep -Fq 'Production APPLY guard' "$DOCTOR"
grep -Fq 'Bare-metal baseline guard' "$DOCTOR"
grep -Fq 'Resource Monitor payload' "$DOCTOR"
grep -Fq 'Resource Monitor CPU' "$DOCTOR"
grep -Fq 'Resource Monitor RAM' "$DOCTOR"
grep -Fq 'Resource Monitor Ethernet' "$DOCTOR"
grep -Fq 'Resource Monitor Wi-Fi' "$DOCTOR"
grep -Fq 'Resource Monitor GPU setting' "$DOCTOR"
grep -Fq 'Arc B580 / xe telemetry' "$DOCTOR"
grep -Fq 'Physical T705' "$DOCTOR"
grep -Fq 'KVM host certification' "$DOCTOR"

for doc in README.md CHANGELOG.md docs/VIRTUALBOX_GNOME_LAB.md docs/GNOME_INTEGRATION.md docs/GNOME_EXTENSIONS.md docs/GNOME_PROFILE.md docs/CI_VALIDATION.md; do
  [[ -f "$ROOT/$doc" ]] || { echo "missing LAB documentation: $doc" >&2; exit 1; }
done

grep -Fq '74408' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq '70326' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq '70909' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq 'Resource Monitor' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq 'scripts/lab/apply-gnome-virtualbox.sh --apply' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq 'install.sh --apply reste interdit' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"

for doc in README.md CHANGELOG.md docs/GNOME_INTEGRATION.md docs/GNOME_EXTENSIONS.md docs/GNOME_PROFILE.md docs/CI_VALIDATION.md; do
  if grep -Eqi 'DING.*(RPM Fedora|paquet Fedora|gnome-shell-extension-desktop-icons-ng)|RPM DING|paquet Fedora DING' "$ROOT/$doc"; then
    echo "stale Fedora RPM DING claim remains in $doc" >&2
    exit 1
  fi
done

if [[ "${CI:-false}" == true ]]; then
  set +e
  output="$(bash "$LAB" --check 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 50 ]] || { echo "CI must be rejected by VirtualBox LAB with rc=50, got $rc" >&2; exit 1; }
  grep -Fq 'VIRTUALBOX GNOME LAB is forbidden' <<<"$output"
fi

echo 'VirtualBox GNOME LAB contract: PASS'
