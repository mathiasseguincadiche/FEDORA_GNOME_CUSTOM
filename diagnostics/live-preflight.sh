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
if [[ "$cmdline" != *rd.live.image* && "$cmdline" != *root=live:* && ! -d /run/initramfs/live ]]; then
  echo "REFUSED: no evidence of a Live environment; never run this on an installed host." >&2; exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/live_preflight_probe.sh"
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
  # Scan the exact PCI function, never a nearby device's xe driver.
  gpu_state="$(live_b580_binding_status "$pci")"
  case "$gpu_state" in
    bound) emit PASS gpu "Arc B580 PCI 8086:e20b uses xe (Live only)" ;;
    driver-unverified) emit FAIL gpu "Arc B580 present but its active xe binding is unverified" ;;
    absent) emit FAIL gpu "Arc B580 PCI ID 8086:e20b absent" ;;
  esac
  if grep -Eiq 'Ethernet controller' <<<"$pci"; then emit PASS ethernet "Ethernet PCI controller detected; link/5GbE not certified"; else emit NOT_TESTED ethernet "no Ethernet PCI controller visible"; fi
  if grep -Eiq 'Network controller' <<<"$pci"; then emit PASS wifi "PCI wireless controller detected; Wi-Fi 7/6GHz not certified"; else emit NOT_TESTED wifi "PCI wireless controller not visible"; fi
else emit NOT_TESTED pci "lspci unavailable"; emit NOT_TESTED gpu "lspci unavailable"; emit NOT_TESTED ethernet "lspci unavailable"; emit NOT_TESTED wifi "lspci unavailable"; fi
if [[ -r /sys/class/dmi/id/board_name ]]; then
  board="$(cat /sys/class/dmi/id/board_name)"
  if [[ "$board" == *"MAG B850M MORTAR WIFI"* ]]; then
    emit PASS motherboard "MSI MAG B850M MORTAR WIFI identity verified"
  else
    emit FAIL motherboard "expected MSI MAG B850M MORTAR WIFI; found ${board:-unknown}"
  fi
else emit NOT_TESTED motherboard "DMI inaccessible"; fi

if [[ -r /proc/cpuinfo ]]; then
  cpu="$(awk -F: '/^model name[[:space:]]*:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)"
  if [[ "$cpu" == *"AMD Ryzen 7 7700"* ]]; then
    emit PASS cpu "AMD Ryzen 7 7700 detected (performance not tested)"
  elif [[ -n "$cpu" ]]; then
    emit FAIL cpu "expected Ryzen 7 7700, found $cpu"
  else
    emit NOT_TESTED cpu "CPU model unavailable"
  fi
else emit NOT_TESTED cpu "proc/cpuinfo unavailable"; fi

if command -v lsblk >/dev/null 2>&1; then
  disks="$(lsblk -dn -o NAME,TRAN,MODEL 2>/dev/null || true)"
  nvme_state="$(live_t705_status "$disks")"
  case "$nvme_state" in
    match) emit PASS nvme "two Crucial T705 NVMe devices present (identities only; no writes)" ;;
    model-unverified) emit NOT_TESTED nvme "two NVMe devices, but both T705 models not readable" ;;
    count-mismatch) emit FAIL nvme "expected exactly two NVMe devices; count or enumeration differs" ;;
    model-mismatch) emit FAIL nvme "expected exactly two Crucial T705 models" ;;
  esac
else emit NOT_TESTED nvme "lsblk unavailable"; fi
if [[ ${XDG_SESSION_TYPE:-} == wayland ]]; then emit PASS session "Wayland"; else emit NOT_TESTED session "Wayland not confirmed"; fi
emit NOT_TESTED display "1440p/240Hz, full vs limited RGB, HDR/SDR, ICC, white level and artifacts require interactive inspection"
emit NOT_TESTED audio "ALC4080 playback/capture require interactive inspection"
emit NOT_TESTED suspend "suspend/resume cycles require controlled manual testing"
emit NOT_TESTED installed "bootloader, SELinux persistence, storage layout, rollback, backup and Gate 3 cannot be certified in Live"
printf 'SUMMARY\tPASS=%s\tFAIL=%s\tNOT_TESTED=%s\n' "$pass" "$fail" "$unknown"
(( fail == 0 )) || exit 1
# NOT_TESTED never means a full hardware certification.
