#!/usr/bin/env bash
# Golden workstation specification: the owner's desktop, display and storage
# targets, the module wiring and the forbidden blind quirks. Behaviour is
# exercised by test_golden_workstation_behavior.sh; the kernel policy by
# test_kernel_lifecycle_contract.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "golden workstation contract: FAIL: $*" >&2; exit 1; }

(
  set +u
  for conf in gnome display performance; do source "$ROOT/config/$conf.conf"; done
  [[ "$ENABLE_BLUR_MY_SHELL" == false && "$GNOME_WINDOW_BUTTONS_ENABLED" == true \
    && "$GNOME_WINDOW_BUTTON_LAYOUT" == ':minimize,maximize,close' ]] || fail 'GNOME targets changed'
  [[ "$DISPLAY_TARGET_REFRESH_HZ" == 240 && "$DISPLAY_TARGET_RGB_RANGE" == full ]] || fail 'display targets changed'
  [[ "$NAUTILUS_COLDSTART_TARGET_MS" == 1200 && "$FINAL_CERT_MIN_SUSPEND_CYCLES" == 5 ]] || fail 'performance targets changed'
)

# Persistent second-T705 user data is a first-class Golden storage socle.
grep -Fxq 'desktop.persistent_data|DESKTOP|gnome.validation|modules/desktop/25_persistent_data.sh' "$ROOT/manifests/module-plan.conf" \
  || fail 'persistent data module not planned after GNOME validation'
grep -Fq 'system.kernel' "$ROOT/manifests/module-plan.conf" || fail 'kernel module not planned'
grep -Fq 'diagnostics/data-storage-doctor' "$ROOT/diagnostics/desktop-integration-doctor" || fail 'desktop doctor skips /data'
grep -Fq 'diagnostics/virtualization-doctor' "$ROOT/diagnostics/final-certification" || fail 'final certification skips KVM'

if grep -RInE 'mem_sleep_default=|xe\.force_probe|i915\.force_probe|pcie_aspm=off|nvme_core\.default_ps_max_latency_us' \
  "$ROOT/config" "$ROOT/modules" "$ROOT/scripts"; then
  fail 'blind kernel/power quirk found'
fi
echo 'golden workstation contract: PASS'
