#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"

runtime_is_baremetal || { ui_error 'Golden release capture is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
baseline_certification_valid || { ui_error 'A valid hardware baseline is required before Golden release capture'; exit "$EXIT_PRECHECK_FAILED"; }
hardware_b580_pcie_validate || { ui_error 'Arc B580 PCIe/ReBAR qualification is not valid'; exit "$EXIT_POSTCHECK_FAILED"; }
storage_nvme_validate_all_expected || { ui_error 'T705 SMART/PCIe qualification is not valid'; exit "$EXIT_POSTCHECK_FAILED"; }
kernel_lifecycle_require_fedora_fallback || exit $?

release_root="$STATE_ROOT/releases"
short_sha="$(repo_commit | cut -c1-12)"
release_id="$(date -u +%Y%m%dT%H%M%SZ)-$short_sha"
final_dir="$release_root/$release_id"
staging="$(mktemp -d "$release_root/.${release_id}.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

rpm_file="$staging/rpm-nevra.tsv"
flatpak_file="$staging/flatpak-commits.tsv"
ext_file="$staging/gnome-extensions.tsv"
runtime_file="$staging/runtime-stack.tsv"
repos_file="$staging/enabled-repositories.txt"
hardware_file="$staging/hardware-ids.txt"
media_file="$staging/fedora44-media.lock"

rpm -qa --qf '%{NAME}\t%{EPOCHNUM}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' | sort -u > "$rpm_file"

if command_exists flatpak; then
  if flatpak list --app --columns=application,branch,origin,active > "$flatpak_file" 2>/dev/null; then
    :
  else
    printf 'application\tbranch\torigin\tcommit\n' > "$flatpak_file"
    while IFS= read -r app; do
      [[ -n "$app" ]] || continue
      commit="$(flatpak info --show-commit "$app" 2>/dev/null || true)"
      printf '%s\tunknown\tunknown\t%s\n' "$app" "${commit:-unknown}" >> "$flatpak_file"
    done < <(flatpak list --app --columns=application 2>/dev/null | sort -u)
  fi
else
  printf 'flatpak-unavailable\n' > "$flatpak_file"
fi

python3 - "$HOME" > "$ext_file" <<'PY'
from pathlib import Path
import hashlib
import json
import sys
home = Path(sys.argv[1])
roots = [(home / '.local/share/gnome-shell/extensions', 'user'), (Path('/usr/share/gnome-shell/extensions'), 'system')]
seen = set()
print('uuid\tscope\tversion\tcontent_sha256')
for root, scope in roots:
    if not root.is_dir():
        continue
    for ext in sorted(p for p in root.iterdir() if p.is_dir()):
        uuid = ext.name
        if (scope, uuid) in seen:
            continue
        seen.add((scope, uuid))
        version = 'unknown'
        meta = ext / 'metadata.json'
        if meta.is_file():
            try:
                data = json.loads(meta.read_text(encoding='utf-8'))
                version = str(data.get('version', 'unknown'))
            except Exception:
                pass
        h = hashlib.sha256()
        for path in sorted(p for p in ext.rglob('*') if p.is_file()):
            rel = path.relative_to(ext).as_posix().encode()
            h.update(rel + b'\0')
            h.update(path.read_bytes())
        print(f'{uuid}\t{scope}\t{version}\t{h.hexdigest()}')
PY

{
  printf 'component\tversion\n'
  printf 'kernel\t%s\n' "$(uname -r)"
  printf 'fedora_fallback\t%s\n' "$(kernel_lifecycle_fedora_fallback_release)"
  for pkg in ${FINAL_CERT_FINGERPRINT_PACKAGES:-linux-firmware intel-gpu-firmware mesa-dri-drivers mesa-vulkan-drivers mutter gnome-shell} qemu-kvm libvirt; do
    printf '%s\t%s\n' "$pkg" "$(runtime_component_version "$pkg")"
  done
} > "$runtime_file"

if command_exists dnf5; then
  dnf5 repolist --enabled > "$repos_file" 2>&1
else
  dnf repolist --enabled > "$repos_file" 2>&1
fi

{
  printf '[identity]\n'
  printf 'board=%s\n' "$(baseline_hw_value /sys/class/dmi/id/board_name)"
  printf 'bios=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_version)"
  printf 'bios_date=%s\n' "$(baseline_hw_value /sys/class/dmi/id/bios_date)"
  printf 'cpu=%s\n' "$(baseline_cpu_model)"
  printf 'hardware_fingerprint=%s\n' "$(baseline_fingerprint)"
  printf 'runtime_fingerprint=%s\n' "$(workstation_runtime_fingerprint)"
  printf 'display_edid_sha256=%s\n' "$(hardware_b580_expected_edid_sha256)"
  printf '\n[b580]\n'
  bdf="$(hardware_expected_gpu_bdf)"; printf 'bdf=%s\n' "$bdf"
  hardware_pcie_link_caps "$bdf"
  printf 'largest_bar_bytes=%s\n' "$(hardware_pci_largest_bar_bytes "$bdf")"
  printf 'rebar=PASS\n'
  printf '\n[nvme]\n'
  while IFS= read -r dev; do
    printf 'device=%s\n' "$dev"
    name="${dev#/dev/}"
    printf 'model=%s\nserial=%s\nfirmware=%s\n' \
      "$(baseline_hw_value "/sys/class/nvme/$name/model")" \
      "$(baseline_hw_value "/sys/class/nvme/$name/serial")" \
      "$(baseline_hw_value "/sys/class/nvme/$name/firmware_rev")"
    nbdf="$(storage_nvme_controller_bdf "$dev")"; hardware_pcie_link_caps "$nbdf"
    storage_nvme_health_json "$dev" | storage_nvme_health_summary
  done < <(storage_nvme_expected_controllers)
  printf '\n[pci]\n'; lspci -Dnnk 2>/dev/null || true
  printf '\n[usb]\n'; lsusb 2>/dev/null || true
  printf '\n[drm-edid]\n'; baseline_edid_hashes
} > "$hardware_file"

cp "$REPO_ROOT/installer/fedora44-media.lock" "$media_file"

(
  cd "$staging"
  sha256sum rpm-nevra.tsv flatpak-commits.tsv gnome-extensions.tsv runtime-stack.tsv enabled-repositories.txt hardware-ids.txt fedora44-media.lock > MANIFEST.sha256
)

media_value() {
  awk -F= -v key="$1" '$1==key {print $2; exit}' "$media_file"
}
file_hash() { sha256sum "$1" | awk '{print $1}'; }

microcode="$(baseline_hw_value /sys/devices/system/cpu/microcode/version unavailable)"
python3 - "$staging/golden-release.json" <<PY
import json
from pathlib import Path
out = Path("$staging/golden-release.json")
data = {
    "schema": 1,
    "project_version": Path("$REPO_ROOT/VERSION").read_text(encoding="utf-8").strip(),
    "project_commit": "$(repo_commit)",
    "effective_config_sha256": "$(effective_config_sha256)",
    "module_plan_sha256": "$(module_plan_sha256)",
    "hardware_fingerprint": "$(baseline_fingerprint)",
    "runtime_fingerprint": "$(workstation_runtime_fingerprint)",
    "kernel": "$(uname -r)",
    "fedora_fallback": "$(kernel_lifecycle_fedora_fallback_release)",
    "bios": "$(baseline_hw_value /sys/class/dmi/id/bios_version)",
    "bios_date": "$(baseline_hw_value /sys/class/dmi/id/bios_date)",
    "amd_microcode_runtime": "$microcode",
    "arc_b580": {
        "pci_id": "8086:e20b",
        "bdf": "$(hardware_expected_gpu_bdf)",
        "driver": "${EXPECTED_GPU_KERNEL_DRIVER:-xe}",
        "rebar": "PASS",
        "pcie_width": "x8",
        "edid_sha256": "$(hardware_b580_expected_edid_sha256)",
    },
    "fedora_media": {
        "release": "$(media_value FEDORA_RELEASE)",
        "compose": "$(media_value FEDORA_COMPOSE)",
        "iso_filename": "$(media_value ISO_FILENAME)",
        "iso_sha256": "$(media_value ISO_SHA256)",
        "checksum_filename": "$(media_value CHECKSUM_FILENAME)",
    },
    "inventories": {
        "rpm_nevra_sha256": "$(file_hash "$rpm_file")",
        "flatpak_commits_sha256": "$(file_hash "$flatpak_file")",
        "gnome_extensions_sha256": "$(file_hash "$ext_file")",
        "runtime_stack_sha256": "$(file_hash "$runtime_file")",
        "enabled_repositories_sha256": "$(file_hash "$repos_file")",
        "hardware_ids_sha256": "$(file_hash "$hardware_file")",
        "fedora_media_lock_sha256": "$(file_hash "$media_file")",
        "manifest_sha256": "$(file_hash "$staging/MANIFEST.sha256")",
    },
    "captured_utc": "$(date -u +%FT%TZ)",
}
out.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

python3 -m json.tool "$staging/golden-release.json" >/dev/null
mkdir -p "$release_root"
[[ ! -e "$final_dir" ]] || { ui_error "Release evidence directory already exists: $final_dir"; exit "$EXIT_POSTCHECK_FAILED"; }
mv "$staging" "$final_dir"
trap - EXIT
chmod -R go-rwx "$final_dir"
printf '%s\n' "$final_dir/golden-release.json"
