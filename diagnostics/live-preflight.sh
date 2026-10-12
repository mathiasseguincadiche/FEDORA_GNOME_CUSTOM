#!/usr/bin/env bash
# Read-only pre-installation audit. No sudo, installation, mounts or device writes.
set -Eeuo pipefail
export LC_ALL=C
if [[ ${1:-} != "" && ${1:-} != "--help" ]]; then echo "Usage: bash diagnostics/live-preflight.sh" >&2; exit 2; fi
if [[ ${1:-} == "--help" ]]; then echo "Read-only Fedora Live USB preflight; prints TSV to stdout."; exit 0; fi
if (( EUID == 0 )); then echo "REFUSED: run as an unprivileged Live session user." >&2; exit 2; fi
if [[ ! -r /etc/os-release ]]; then echo "REFUSED: cannot identify operating system." >&2; exit 2; fi
source /etc/os-release
if [[ ${ID:-} != fedora ]]; then echo "REFUSED: Fedora Live environment required." >&2; exit 2; fi
cmdline="$(cat /proc/cmdline 2>/dev/null || true)"
root_type="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
if [[ "$cmdline" != *rd.live.image* && "$cmdline" != *root=live:* && "$root_type" != overlay && ! -d /run/initramfs/live ]]; then
  echo "REFUSED: no evidence of a Live environment; never run this on an installed host." >&2; exit 2
fi
pass=0; fail=0; unknown=0
emit() {
  local status="$1" name="$2" detail="$3"
  detail="${detail//$'\n'/ }"; detail="${detail//$'\t'/ }"
  printf '%s\t%s\t%s\n' "$status" "$name" "$detail"
  case "$status" in PASS) ((pass+=1));; FAIL) ((fail+=1));; NOT_TESTED) ((unknown+=1));; esac
}
printf 'STATUS\tCHECK\tDETAIL\n'
if [[ ${VERSION_ID:-} == 45 ]]; then emit PASS os "Fedora 45"; else emit FAIL os "expected Fedora 45; got ${VERSION_ID:-unknown}"; fi
kernel="$(uname -r)"
emit PASS kernel "$kernel (Live kernel only)"
if command -v gnome-shell >/dev/null 2>&1; then
  gnome_ver="$(gnome-shell --version 2>/dev/null || true)"
  if [[ "$gnome_ver" =~ GNOME\ Shell\ 51([.[:space:]]|$) ]]; then emit PASS gnome "$gnome_ver"; else emit FAIL gnome "${gnome_ver:-version unknown}; expected 51"; fi
else emit NOT_TESTED gnome "gnome-shell unavailable"; fi
if command -v lspci >/dev/null 2>&1; then
  pci="$(lspci -Dnnk 2>/dev/null || true)"
  if grep -Eiq '8086:e20b' <<<"$pci"; then
    gpu_block="$(grep -i -A 5 '8086:e20b' <<<"$pci" | head -n 6)"
    if grep -Eq 'Kernel driver in use: xe' <<<"$gpu_block"; then emit PASS gpu "Arc B580 (8086:e20b) bound to xe"; else emit FAIL gpu "Arc B580 detected; xe binding not confirmed"; fi
  else emit FAIL gpu "Arc B580 PCI ID 8086:e20b absent"; fi
  if grep -Eiq 'Ethernet controller' <<<"$pci"; then emit PASS ethernet "Ethernet PCI controller detected; link/5GbE not certified"; else emit NOT_TESTED ethernet "no Ethernet PCI controller visible"; fi
  if grep -Eiq 'Network controller' <<<"$pci"; then emit PASS wifi "PCI wireless controller detected; Wi-Fi 7/6GHz not certified"; else emit NOT_TESTED wifi "PCI wireless controller not visible"; fi
else emit NOT_TESTED pci "lspci unavailable"; emit NOT_TESTED gpu "lspci unavailable"; emit NOT_TESTED ethernet "lspci unavailable"; emit NOT_TESTED wifi "lspci unavailable"; fi
if [[ -r /sys/class/dmi/id/board_name ]]; then emit PASS motherboard "$(cat /sys/class/dmi/id/board_name) (identity only)"; else emit NOT_TESTED motherboard "DMI inaccessible"; fi
if command -v lsblk >/dev/null 2>&1; then
  nvme="$(lsblk -dn -o NAME,MODEL,TRAN 2>/dev/null | awk '$3=="nvme" {print $1":"$2}' | paste -sd, -)"
  [[ -n "$nvme" ]] && emit PASS nvme "$nvme (enumeration only; no writes)" || emit NOT_TESTED nvme "NVMe not enumerated"
else emit NOT_TESTED nvme "lsblk unavailable"; fi
if [[ ${XDG_SESSION_TYPE:-} == wayland ]]; then emit PASS session "Wayland"; else emit NOT_TESTED session "Wayland not confirmed"; fi
emit NOT_TESTED display "1440p/240Hz, EDID, color and artifacts require interactive inspection"
emit NOT_TESTED audio "ALC4080 playback/capture require interactive inspection"
emit NOT_TESTED suspend "suspend/resume cycles require controlled manual testing"
emit NOT_TESTED installed "bootloader, SELinux persistence, storage layout, rollback, backup and Gate 3 cannot be certified in Live"
printf 'SUMMARY\tPASS=%s\tFAIL=%s\tNOT_TESTED=%s\n' "$pass" "$fail" "$unknown"
(( fail == 0 )) || exit 1
# NOT_TESTED never means a full hardware certification.
