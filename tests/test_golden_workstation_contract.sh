#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'KERNEL_VANILLA_COPR="@kernel-vanilla/stable"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_MIN_VERSION="7.2.2"' "$ROOT/config/kernel.conf"
grep -Fxq 'mode=rolling-n-nminus1' "$ROOT/config/kernel-lifecycle.policy"
grep -Fxq 'max_installed_kernels=2' "$ROOT/config/kernel-lifecycle.policy"
grep -Fxq 'install_latest_direct=true' "$ROOT/config/kernel-lifecycle.policy"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="false"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_BLOCK_SECURE_BOOT="true"' "$ROOT/config/kernel.conf"
grep -Fq 'system.kernel' "$ROOT/manifests/module-plan.conf"
grep -Fq '@kernel-vanilla/stable' "$ROOT/modules/system/01a_kernel_latest_stable.sh"
grep -Fq 'kernel_lifecycle_install_latest' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'KERNEL_VENDOR_CHANGE_ALLOWED' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'installonly_limit=$limit' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'remove --oldinstallonly --limit="$limit"' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'kernel_lifecycle_finalize_update' "$ROOT/scripts/maintenance/update-system.sh"

# Persistent second-T705 user data is a first-class Golden storage socle.
grep -Fq 'desktop.persistent_data|DESKTOP|gnome.validation|modules/desktop/25_persistent_data.sh' "$ROOT/manifests/module-plan.conf"
for file in lib/persistent_data.sh modules/desktop/25_persistent_data.sh diagnostics/data-storage-doctor; do
  [[ -s "$ROOT/$file" ]] || { echo "missing persistent data file: $file" >&2; exit 1; }
done
for path in '/data/Documents' '/data/Projets' '/data/ISO' '/data/Jeux'; do
  grep -Fq "$path" "$ROOT/modules/desktop/25_persistent_data.sh" || { echo "persistent data module missing $path" >&2; exit 1; }
done
grep -Fq 'persistent_data_games' "$ROOT/lib/persistent_data.sh"
grep -Fq 'xdg-user-dirs-update --set DOCUMENTS' "$ROOT/modules/desktop/25_persistent_data.sh"
grep -Fq 'user_home_t' "$ROOT/modules/desktop/25_persistent_data.sh"
grep -Fq 'diagnostics/data-storage-doctor' "$ROOT/diagnostics/desktop-integration-doctor"
grep -Fq '/data/{Documents,Projets,ISO,Jeux}' "$ROOT/diagnostics/data-storage-doctor"

grep -Fq 'ENABLE_BLUR_MY_SHELL="false"' "$ROOT/config/gnome.conf"
grep -Fq 'GNOME_WINDOW_BUTTONS_ENABLED="true"' "$ROOT/config/gnome.conf"
grep -Fq 'GNOME_WINDOW_BUTTON_LAYOUT=":minimize,maximize,close"' "$ROOT/config/gnome.conf"
grep -Fq 'gsettings set org.gnome.desktop.wm.preferences button-layout' "$ROOT/modules/gnome/23_gnome_settings.sh"
grep -Fq 'window button layout mismatch' "$ROOT/modules/gnome/23_gnome_settings.sh"
grep -Fq 'NAUTILUS_COLDSTART_TARGET_MS="1200"' "$ROOT/config/performance.conf"
grep -Fq 'org.gnome.Nautilus' "$ROOT/diagnostics/nautilus-coldstart-doctor"
grep -Fq 'workstation_runtime_fingerprint' "$ROOT/diagnostics/nautilus-coldstart-doctor"
grep -Fq 'DISPLAY_TARGET_REFRESH_HZ="240"' "$ROOT/config/display.conf"
grep -Fq 'DISPLAY_TARGET_RGB_RANGE="full"' "$ROOT/config/display.conf"
grep -Fq 'DISPLAY_CERT_TOLERANCE_HZ' "$ROOT/diagnostics/display-doctor"
grep -Fq -- '--rgb-range' "$ROOT/scripts/gnome/display-repair.sh"
grep -Fq 'PrepareForSleep' "$ROOT/scripts/gnome/display-watch.sh"
grep -Fq 'MonitorsChanged' "$ROOT/scripts/gnome/display-watch.sh"
grep -Fq 'subsystem-match=drm' "$ROOT/scripts/gnome/display-watch.sh"
grep -Fq 'FINAL_CERT_MIN_SUSPEND_CYCLES="5"' "$ROOT/config/performance.conf"
grep -Fq 'record-suspend' "$ROOT/diagnostics/final-certification"
grep -Fq 'diagnostics/virtualization-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'EFFACER' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'ignoredisk --only-use=' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'Repository SHA:' "$ROOT/installer/generate-fedora44-kickstart.sh"
! grep -RInE 'mem_sleep_default=|xe\.force_probe|i915\.force_probe|pcie_aspm=off|nvme_core\.default_ps_max_latency_us' "$ROOT/config" "$ROOT/modules" "$ROOT/scripts" || { echo 'blind kernel/power quirk found' >&2; exit 1; }
echo 'golden workstation contract: PASS'
