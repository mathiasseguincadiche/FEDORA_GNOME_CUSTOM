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
# Five quick compatibility checks only: no stress tests, installs or disk writes.
# A hardware/driver PASS never certifies a deployed Fedora installation.
pass=0; fail=0; unknown=0
emit() {
  local status="$1" name="$2" detail="$3"
  detail="$(printf '%s' "$detail" | tr '\t\n' '  ')"
  printf '%s\t%s\t%s\n' "$status" "$name" "$detail"
  case "$status" in
    PASS) ((pass+=1));;
    FAIL) ((fail+=1));;
    NOT_TESTED) ((unknown+=1));;
  esac
}
manual_check() {
  local name="$1" question="$2" detail="$3" answer='' state='NOT_TESTED'
  # The report may be piped to tee; collect human evidence from the terminal.
  # Without a controlling terminal, an unanswered question cannot be a PASS.
  if [[ -t 2 && -r /dev/tty ]]; then
    if IFS= read -r -p "$question [o/n/?] " answer </dev/tty; then
      state="$(live_manual_status "$answer")"
    fi
  fi
  emit "$state" "$name" "$detail"
}
printf 'STATUS\tCHECK\tDETAIL\n'
gnome_ver=''
if command -v gnome-shell >/dev/null 2>&1; then
  gnome_ver="$(gnome-shell --version 2>/dev/null || true)"
fi
# Check 1: the actual Live GNOME Wayland session, not just installed packages.
if [[ -v VERSION_ID && "$VERSION_ID" == 45 &&
      "$gnome_ver" =~ GNOME[[:space:]]Shell[[:space:]]51([.[:space:]]|$) &&
      -v XDG_SESSION_TYPE && "$XDG_SESSION_TYPE" == wayland ]]; then
  emit PASS session "Fedora 45 / $gnome_ver / Wayland"
else
  emit FAIL session "Expected a running Fedora 45 / GNOME 51 / Wayland Live session"
fi
# Check 2: Intel Arc B580 must be bound to xe on its own PCI function.
if command -v lspci >/dev/null 2>&1; then
  pci="$(lspci -Dnnk 2>/dev/null || true)"
  case "$(live_b580_binding_status "$pci")" in
    bound) emit PASS gpu 'Intel Arc B580 (8086:e20b) bound to xe';;
    *) emit FAIL gpu 'B580 absent or not confirmed bound to xe';;
  esac
else
  emit NOT_TESTED gpu 'lspci unavailable: driver binding not proven'
fi
# Check 3: identity only. Never mount, repair, format or benchmark either SSD.
if command -v lsblk >/dev/null 2>&1; then
  disks="$(lsblk -dn -o NAME,TRAN,MODEL 2>/dev/null || true)"
  case "$(live_t705_status "$disks")" in
    match) emit PASS storage 'Two Crucial T705 NVMe detected (no writes)';;
    model-unverified) emit NOT_TESTED storage 'Both T705 model identities not readable';;
    *) emit FAIL storage 'Expected exactly two Crucial T705 NVMe';;
  esac
else
  emit NOT_TESTED storage 'lsblk unavailable: SSD identities not proven'
fi
# Checks 4-5 need real human observation; no fake automation/auto-PASS.
manual_check display 'Image 2560x1440 / 240 Hz correcte, sans artefacts visibles ?' \
  'Inspect GNOME Display settings and a white window; no HDR/colorimetry certification'
manual_check network 'Connexion Internet fonctionnelle (clone GitHub ou page HTTPS reussie) ?' \
  'Actual Internet access; no Wi-Fi 7 / 5GbE throughput benchmark'
verdict="$(live_go_decision "$fail" "$unknown")"
printf 'SUMMARY\tPASS=%s\tFAIL=%s\tNOT_TESTED=%s\n' "$pass" "$fail" "$unknown"
case "$verdict" in
  GO) printf 'DECISION\tGO\tLive USB compatible pour passer a la preparation securisee de l installation\n';;
  NO-GO) printf 'DECISION\tNO-GO\tCorriger chaque FAIL avant installation\n';;
  *) printf 'DECISION\tA_VERIFIER\tUn controle essentiel manque : pas de GO automatique\n';;
esac
[[ "$verdict" == GO ]]
