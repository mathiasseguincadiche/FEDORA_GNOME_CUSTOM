#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$ROOT/config/gnome.conf"
INSTALLER="$ROOT/scripts/gnome/install-resource-monitor.sh"
MODULE="$ROOT/modules/gnome/24b_resource_monitor.sh"
DOCTOR="$ROOT/diagnostics/resource-monitor-doctor"
PLAN="$ROOT/manifests/module-plan.conf"

for file in "$CONF" "$INSTALLER" "$MODULE" "$DOCTOR" "$PLAN"; do
  [[ -f "$file" ]] || { echo "Resource Monitor contract file missing: $file" >&2; exit 1; }
done
bash -n "$INSTALLER"; bash -n "$MODULE"; bash -n "$DOCTOR"

for token in \
  'ENABLE_RESOURCE_MONITOR="true"' \
  'RESOURCE_MONITOR_REFRESH_SECONDS="2"'; do
  grep -Fq "$token" "$CONF" || { echo "Resource Monitor config missing: $token" >&2; exit 1; }
done

grep -Fq 'gnome.telemetry|GNOME|gnome.extensions|modules/gnome/24b_resource_monitor.sh' "$PLAN"
grep -Fq 'gnome.polish|GNOME|gnome.telemetry|modules/gnome/24c_ubuntu_polish.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'gnome.display_repair|GNOME|gnome.polish|modules/gnome/25_display_repair.sh' "$PLAN"



for token in \
  '0x8086' '0xe20b' 'gpu_busy_percent' 'gt_busy_percent' 'k10temp|zenpower' \
  "itemsposition \"['cpu', 'ram', 'eth', 'wlan', 'gpu']\"" \
  'diskstatsstatus false' 'swapstatus false' 'netautohidestatus true' \
  'thermaltemperatureunit' 'gpustatus' 'runtime_is_baremetal' \
  'Resource Monitor has no readable B580 xe GPU load source'; do
  grep -Fq "$token" "$MODULE" || { echo "Resource Monitor module invariant missing: $token" >&2; exit 1; }
done

for token in 'Ryzen CPU temperature source' 'Intel Arc B580' 'B580 GPU load source' 'B580 temperature source' 'EXPECTED' 'runtime_is_baremetal'; do
  grep -Fq "$token" "$DOCTOR" || { echo "Resource Monitor doctor invariant missing: $token" >&2; exit 1; }
done

for forbidden in 'run_mutating' 'sudo ' 'dnf -y install' 'gnome-extensions install'; do
  if grep -Fq "$forbidden" "$DOCTOR"; then
    echo "Resource Monitor doctor must remain read-only: $forbidden" >&2; exit 1
  fi
done

if grep -RFiq 'Astra Monitor' "$ROOT/config" "$ROOT/manifests" "$ROOT/modules/gnome" "$ROOT/scripts/gnome"; then
  echo 'Astra Monitor must not be part of the Golden telemetry profile' >&2; exit 1
fi

echo 'Resource Monitor telemetry contract: PASS'
