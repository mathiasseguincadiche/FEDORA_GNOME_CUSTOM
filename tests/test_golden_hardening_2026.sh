#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for file in \
  lib/evidence.sh \
  lib/hardware_profile.sh \
  lib/storage_health.sh \
  scripts/hardware/opencl-smoke.py \
  scripts/hardware/vaapi-smoke.sh \
  scripts/release/capture-golden-release.sh \
  installer/fedora44-media.lock \
  installer/verify-fedora44-media.sh \
  docs/GOLDEN_RELEASE.md \
  docs/RUNBOOK_GOLDEN_HARDWARE.md \
  docs/adr/README.md; do
  [[ -s "$ROOT/$file" ]] || { echo "missing Golden hardening file: $file" >&2; exit 1; }
done

# APPLY identity is commit + effective config + module plan + physical hardware.
grep -Fq 'effective_config_sha256' "$ROOT/lib/evidence.sh"
grep -Fq 'module_plan_sha256' "$ROOT/lib/evidence.sh"
grep -Fq 'hardware_fingerprint' "$ROOT/lib/apply_gate.sh"
grep -Fq 'evidence_require_current_identity' "$ROOT/lib/apply_gate.sh"
grep -Fq 'backup_runtime_validate_preapply_marker' "$ROOT/lib/apply_gate.sh"
grep -Fq 'restic cat snapshot' "$ROOT/lib/backup_runtime.sh"
grep -Fq 'fedora-gnome-custom-preapply' "$ROOT/lib/backup_runtime.sh"
grep -Fq 'effective_config_sha256' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'backup_runtime_validate_preapply_marker' "$ROOT/prepare-preapply-backup.sh"

# Arc B580 is certified by PCI identity, xe, x8 capability and ReBAR; display binds to its EDID.
grep -Fq 'EXPECTED_GPU_PCI_DEVICE' "$ROOT/lib/hardware_profile.sh"
grep -Fq 'current_link_width' "$ROOT/lib/hardware_profile.sh"
grep -Fq 'max_link_width' "$ROOT/lib/hardware_profile.sh"
grep -Fq 'Resizable BAR' "$ROOT/lib/hardware_profile.sh"
grep -Fq 'hardware_b580_rebar_enabled' "$ROOT/lib/hardware_profile.sh"
grep -Fq 'hardware_b580_capture_display_profile' "$ROOT/lib/baseline.sh"
grep -Fq 'display-profile.env' "$ROOT/scripts/gnome/display-repair.sh"
grep -Fq '0xe20b' "$ROOT/scripts/gnome/display-repair.sh"
grep -Fq 'expected_edid' "$ROOT/scripts/gnome/display-repair.sh"
if grep -Fq 'connected_connector()' "$ROOT/scripts/gnome/display-repair.sh"; then
  echo 'display repair regressed to first-connected connector selection' >&2
  exit 1
fi

# Both T705 controllers are strict SMART + PCIe 5.0 x4 certification surfaces.
grep -Fq 'critical_warning' "$ROOT/lib/storage_health.sh"
grep -Fq 'media_errors' "$ROOT/lib/storage_health.sh"
grep -Fq 'available_spare_threshold' "$ROOT/lib/storage_health.sh"
grep -Fq 'percentage_used' "$ROOT/lib/storage_health.sh"
grep -Fq 'max_link_speed' "$ROOT/lib/storage_health.sh"
grep -Fq 'curw >= 4' "$ROOT/lib/storage_health.sh"
grep -Fq 's >= 32.0' "$ROOT/lib/storage_health.sh"
grep -Fq 'storage_nvme_validate_controller' "$ROOT/diagnostics/storage-doctor"
grep -Fq 'storage_nvme_kernel_health' "$ROOT/diagnostics/storage-doctor"
grep -Fq 'diagnostics/storage-doctor' "$ROOT/diagnostics/final-certification"

# Persistent second-T705 user data is centralized in lib/persistent_data.sh and
# the doctor must validate the whole catalog instead of duplicating path logic.
for helper in persistent_data_documents persistent_data_projects persistent_data_iso persistent_data_games persistent_data_layout_paths; do
  grep -Fq "$helper" "$ROOT/lib/persistent_data.sh" || { echo "persistent data helper missing $helper" >&2; exit 1; }
done
grep -Fq "persistent_data_mount() { printf '%s\\n' '/data'; }" "$ROOT/lib/persistent_data.sh"
grep -Fq 'source "$REPO_ROOT/lib/persistent_data.sh"' "$ROOT/diagnostics/data-storage-doctor"
grep -Fq 'persistent_data_layout_paths' "$ROOT/diagnostics/data-storage-doctor"
grep -Fq '/data/{Documents,Projets,ISO,Jeux}' "$ROOT/diagnostics/data-storage-doctor"

# Kernel latest-stable is installed directly with a strict N/N-1 retention.
grep -Fq 'kernel_lifecycle_vanilla_repo_id' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq -- "--repo=\"\$repo\"" "$ROOT/lib/kernel_lifecycle.sh"
if grep -Fq -- '--repoid=' "$ROOT/lib/kernel_lifecycle.sh"; then
  echo 'legacy DNF4 --repoid syntax found in DNF5 kernel resolver' >&2
  exit 1
fi
grep -Fq "qf $'%{VERSION}-%{RELEASE}.%{ARCH}\\n'" "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'kernel_lifecycle_latest_nevras' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'Kernel install mismatch' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'kernel_lifecycle_version_at_least' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'installonly_limit=$limit' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'remove --oldinstallonly --limit="$limit"' "$ROOT/lib/kernel_lifecycle.sh"
grep -Fq 'rolling N/N-1 max=2' "$ROOT/diagnostics/kernel-doctor"
grep -Fq 'kernel_lifecycle_finalize_update' "$ROOT/scripts/maintenance/update-system.sh"

# GPU capabilities must be exercised, not only enumerated.
grep -Fq 'clEnqueueNDRangeKernel' "$ROOT/scripts/hardware/opencl-smoke.py"
grep -Fq 'verification failed' "$ROOT/scripts/hardware/opencl-smoke.py"
grep -Fq 'h264_vaapi' "$ROOT/scripts/hardware/vaapi-smoke.sh"
grep -Fq 'hevc_vaapi' "$ROOT/scripts/hardware/vaapi-smoke.sh"
grep -Fq 'av1_vaapi' "$ROOT/scripts/hardware/vaapi-smoke.sh"
grep -Fq 'decode=h264,hevc,vp9,av1' "$ROOT/scripts/hardware/vaapi-smoke.sh"
grep -Fq 'opencl-smoke.py' "$ROOT/diagnostics/arc-compute-doctor"
grep -Fq 'vaapi-smoke.sh' "$ROOT/diagnostics/media-doctor"

# Routine package maintenance is an explicit DNF5 offline lifecycle with kernel target evidence.
grep -Fq 'dnf5 --refresh upgrade --offline' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'dnf5 offline reboot' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq -- '--finalize' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'dnf5 check' "$ROOT/scripts/maintenance/update-system.sh"
grep -Fq 'kernel_target=' "$ROOT/scripts/maintenance/update-system.sh"

# Golden release is an exact state attestation with hashed inventories and N/N-1 kernel metadata.
for name in golden-release.json rpm-nevra.tsv flatpak-commits.tsv gnome-extensions.tsv runtime-stack.tsv enabled-repositories.txt hardware-ids.txt fedora44-media.lock MANIFEST.sha256; do
  grep -Fq "$name" "$ROOT/scripts/release/capture-golden-release.sh" || { echo "release capture missing artifact: $name" >&2; exit 1; }
done
grep -Fq 'kernel_n' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'kernel_n_minus_1' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'kernel_grub_default' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'capture-golden-release.sh' "$ROOT/diagnostics/final-certification"
grep -Fq 'golden_release_manifest' "$ROOT/diagnostics/final-certification"
grep -Fq 'diff)' "$ROOT/diagnostics/software-matrix-doctor"

# Fedora installation media is pinned to the reviewed compose and checksum.
grep -Fxq 'FEDORA_RELEASE=44' "$ROOT/installer/fedora44-media.lock"
grep -Fxq 'FEDORA_COMPOSE=1.7' "$ROOT/installer/fedora44-media.lock"
grep -Fxq 'ISO_SHA256=1620295f6a00c27c3208f0c00b8ece4eab1ec69b9002152d97488bf26a426ddf' "$ROOT/installer/fedora44-media.lock"
grep -Fq 'gpgv' "$ROOT/installer/verify-fedora44-media.sh"

# Architecture decisions are explicit and discoverable. ADR 0003 and 0004 are
# historical; ADR 0010 and 0011 are their current replacements.
for adr in 0001-fedora44-gnome50 0002-no-secureboot-no-local-luks 0003-kernel-vanilla-candidate-certified 0004-btrfs-root-ext4-kvm 0005-b580-host-only 0006-fedora-gpu-stack 0007-kvm-network-fail-closed 0008-no-automatic-firmware-flash 0009-three-gate-validation 0010-kernel-rolling-n-nminus1 0011-persistent-second-t705-data-layout; do
  [[ -s "$ROOT/docs/adr/$adr.md" ]] || { echo "missing ADR: $adr" >&2; exit 1; }
done
grep -Fq 'Statut : remplacé' "$ROOT/docs/adr/0003-kernel-vanilla-candidate-certified.md"
grep -Fq 'ADR 0010' "$ROOT/docs/adr/0003-kernel-vanilla-candidate-certified.md"
grep -Fq 'Statut : remplacé par ADR 0011' "$ROOT/docs/adr/0004-btrfs-root-ext4-kvm.md"
grep -Fq 'Second T705 persistant' "$ROOT/docs/adr/0011-persistent-second-t705-data-layout.md"
grep -Fq '/data/Jeux' "$ROOT/docs/adr/0011-persistent-second-t705-data-layout.md"

echo 'September 2026 Golden hardening contract: PASS'
