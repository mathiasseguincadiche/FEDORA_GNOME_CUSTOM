#!/usr/bin/env bash
# Native Live observations only: no installation, SSD writes or automatic sleep.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/live_preflight_probe.sh"

live_report_init() {
  pass=0; fail=0; unknown=0
  optional_pass=0; optional_fail=0; optional_unknown=0
  declare -gA live_emitted=()
  printf 'STATUS\tCHECK\tDETAIL\nSCHEMA\tfgc-live-preflight\t2\n'
}

emit() {
  local status="$1" name="$2" detail="$3" evidence="${4:-automatic}" requirement
  case "$status" in PASS|FAIL|NOT_TESTED) ;; *) return 2 ;; esac
  requirement="$(live_check_requirement "$name")" || return 2
  [[ ! -v "live_emitted[$name]" ]] || return 2
  live_emitted[$name]=true
  detail="$(printf '%s' "$detail" | tr '\t\r\n' '   ')"
  printf '%s\t%s\trequirement=%s evidence=%s; %s\n' "$status" "$name" "$requirement" "$evidence" "$detail"
  if [[ "$requirement" == required ]]; then
    case "$status" in PASS) ((pass+=1));; FAIL) ((fail+=1));; NOT_TESTED) ((unknown+=1));; esac
  else
    case "$status" in PASS) ((optional_pass+=1));; FAIL) ((optional_fail+=1));; NOT_TESTED) ((optional_unknown+=1));; esac
  fi
}

live_manual_answer() {
  local check="$1" question="$2" answer=''
  if [[ -t 2 && -r /dev/tty ]]; then
    IFS= read -r -p "$check: $question [o=essai reussi/n=essai echoue/?=non teste] " answer </dev/tty || true
  fi
  live_manual_status "$answer"
}

manual_check() {
  local name="$1" question="$2" detail="$3" state
  state="$(live_manual_answer "$name" "$question")"
  emit "$state" "$name" "$detail" manual
}

live_report_finish() {
  local id requirement evidence verdict
  while IFS=$'\t' read -r id requirement evidence; do
    [[ -v "live_emitted[$id]" ]] || emit NOT_TESTED "$id" 'No observation collected' "$evidence"
  done < <(live_check_catalog)
  verdict="$(live_go_decision "$((fail+optional_fail))" "$unknown")"
  printf 'SUMMARY\tPASS=%s\tFAIL=%s\tNOT_TESTED=%s\n' "$pass" "$fail" "$unknown"
  printf 'OPTIONAL_SUMMARY\tPASS=%s\tFAIL=%s\tNOT_TESTED=%s\n' "$optional_pass" "$optional_fail" "$optional_unknown"
  case "$verdict" in
    GO) printf 'DECISION\tGO\tPREINSTALL_ONLY: required Live compatibility observed; optional gaps remain explicit; installed system NOT_CERTIFIED\n';;
    NO-GO) printf 'DECISION\tNO-GO\tReview every observed FAIL, including optional peripherals, before installation\n';;
    *) printf 'DECISION\tA_VERIFIER\tRequired Live evidence missing; installed system NOT_CERTIFIED\n';;
  esac
  [[ "$verdict" == GO ]]
}

live_identity_checks() {
  local gnome_ver='' native_rc=127 shell_running=unknown bus='' pci disks state
  if command -v gnome-shell >/dev/null 2>&1; then gnome_ver="$(gnome-shell --version 2>/dev/null || true)"; fi
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    native_rc=0; systemd-detect-virt --quiet >/dev/null 2>&1 || native_rc=$?
  fi
  if command -v gdbus >/dev/null 2>&1 && bus="$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner org.gnome.Shell 2>/dev/null)"; then
    case "$bus" in '(true,)') shell_running=true;; '(false,)') shell_running=false;; esac
  fi
  state="$(live_session_status "${VERSION_ID:-}" "$gnome_ver" "${XDG_SESSION_TYPE:-}" "$native_rc" "$shell_running")"
  emit "$state" session "Fedora=${VERSION_ID:-unknown}; shell=${gnome_ver:-unknown}; running_shell_bus=$shell_running; session=${XDG_SESSION_TYPE:-unknown}; virtualization_probe_rc=$native_rc (1=native, 0=virtualized)"
  if command -v lspci >/dev/null 2>&1 && pci="$(lspci -Dnnk 2>/dev/null)"; then
    case "$(live_b580_binding_status "$pci")" in
      bound) emit PASS gpu 'Intel Arc B580 (8086:e20b) bound to xe; no performance or AV1 certification';;
      *) emit FAIL gpu 'B580 absent or not confirmed bound to xe';;
    esac
  else
    emit NOT_TESTED gpu 'PCI inventory unavailable; driver binding not proven'
  fi
  if command -v lsblk >/dev/null 2>&1 && disks="$(lsblk -dn -o NAME,TRAN,MODEL 2>/dev/null)"; then
    case "$(live_t705_status "$disks")" in
      match) emit PASS storage 'Two Crucial T705 NVMe enumerated read-only; health and installation target NOT_CERTIFIED';;
      model-unverified) emit NOT_TESTED storage 'Both T705 model identities not readable';;
      *) emit FAIL storage 'Expected exactly two Crucial T705 NVMe';;
    esac
  else
    emit NOT_TESTED storage 'Block-device inventory unavailable; SSD identities not proven'
  fi
}

live_display_checks() {
  local report='' modes='' state='NOT_TESTED'
  # --verbose lists advertised modes; plain show marks the actual Current mode.
  if command -v gdctl >/dev/null 2>&1 && report="$(gdctl show 2>/dev/null)"; then
    modes="$(live_current_display_modes "$report")"
    state="$(live_display_mode_status "$modes")"
  fi
  if [[ "$state" == NOT_TESTED ]]; then
    manual_check display_mode 'Dans Parametres > Ecrans, le mode ACTIF indique-t-il 2560x1440 a 240 Hz ?' \
      'Human reading of active GNOME settings; automatic active-mode measurement unavailable or ambiguous'
  else
    emit "$state" display_mode "Active mode=$modes; expected one 2560x1440 display at 240 Hz (+/-1 Hz); no display settings changed"
  fi
  manual_check display 'Image normale, blancs lisibles et mouvements sans artefacts ni ecran noir ?' \
    'Human image/motion observation; no HDR, ICC, OLED or colorimetry certification'
}

live_network_checks() {
  local devices='' kind type iface status index url='https://fedoraproject.org/' network_ok=false
  local -a states=() details=()
  if command -v nmcli >/dev/null 2>&1; then devices="$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)"; fi
  for kind in lan wifi; do
    type=ethernet; [[ "$kind" != wifi ]] || type=wifi
    iface="$(live_connected_interface "$devices" "$type")"
    if [[ -z "$iface" ]]; then
      states+=(NOT_TESTED)
      details+=('No connected interface tested; connect this medium in GNOME and rerun to qualify it')
    elif ! command -v curl >/dev/null 2>&1; then
      states+=(NOT_TESTED)
      details+=("Connected interface=$iface; HTTPS tool unavailable; link presence alone is not connectivity proof")
    else
      status=FAIL
      if curl --interface "$iface" --noproxy '*' --fail --silent --show-error --location --max-time 10 "$url" >/dev/null 2>&1; then
        status=PASS; network_ok=true
      fi
      states+=("$status")
      details+=("Interface=$iface; DNS/TLS/HTTPS request to $url; no Wi-Fi 7 or 5GbE throughput certification")
    fi
  done
  if [[ "$network_ok" == true ]]; then
    emit PASS network 'HTTPS request succeeded through an explicitly tested LAN/Wi-Fi interface'
  elif command -v curl >/dev/null 2>&1 && curl --noproxy '*' --fail --silent --show-error --location --max-time 10 "$url" >/dev/null 2>&1; then
    emit PASS network 'Default-route DNS/TLS/HTTPS request succeeded; individual LAN/Wi-Fi qualification remains explicit'
  else
    manual_check network 'Un acces Internet reel vient-il de reussir (page HTTPS ou clone GitHub) ?' \
      'Explicit human Internet observation; automated HTTPS measurement unavailable or unsuccessful'
  fi
  index=0
  for kind in lan wifi; do
    emit "${states[$index]}" "$kind" "${details[$index]}"
    ((index+=1))
  done
}

live_peripheral_checks() {
  local report='' sinks=0 sources=0 count=0
  if command -v wpctl >/dev/null 2>&1 && report="$(wpctl status 2>/dev/null)"; then
    read -r sinks sources < <(live_audio_device_counts "$report")
    if (( sinks > 0 && sources > 0 )); then
      emit PASS audio_devices "PipeWire output_nodes=$sinks input_nodes=$sources; inventory only, sound/microphone not inferred"
    else
      emit NOT_TESTED audio_devices "PipeWire output_nodes=$sinks input_nodes=$sources; both kinds of audio node not observed"
    fi
  else
    emit NOT_TESTED audio_devices 'PipeWire inventory unavailable; no package installed'
  fi
  manual_check audio_output 'Dans Parametres > Son, avez-vous entendu correctement le test gauche/droite sur la sortie choisie ?' \
    'Human playback observation on selected output; no latency or long-duration audio qualification'
  manual_check microphone 'Dans Parametres > Son, le niveau du micro choisi reagit-il a votre voix et retombe-t-il au silence ?' \
    'Human input-meter response while speaking; recording quality and unselected inputs NOT_TESTED'
  if command -v bluetoothctl >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 && report="$(timeout 6 bluetoothctl list 2>/dev/null)"; then
    count="$(live_bluetooth_controller_count "$report")"
    if (( count > 0 )); then emit PASS bluetooth_controller "BlueZ controllers=$count; inventory only, pairing not inferred"
    else emit NOT_TESTED bluetooth_controller 'No readable BlueZ controller observed; check radio state in GNOME'; fi
  else
    emit NOT_TESTED bluetooth_controller 'BlueZ controller inventory unavailable'
  fi
  manual_check bluetooth 'Avez-vous connecte puis utilise un appareil Bluetooth dans cette session Live ?' \
    'Human connection/use of one peripheral; Bluetooth version, range and other peripherals NOT_TESTED'
  if command -v lsusb >/dev/null 2>&1 && report="$(lsusb 2>/dev/null)"; then
    count="$(live_usb_device_count "$report")"
    if (( count > 0 )); then emit PASS usb_devices "USB devices=$count including root hubs; enumeration only, no SSD opened"
    else emit NOT_TESTED usb_devices 'No readable USB enumeration'; fi
  else
    emit NOT_TESTED usb_devices 'USB inventory tool unavailable'
  fi
  manual_check usb 'Avez-vous utilise les peripheriques USB prevus (clavier/souris/camera), sans ouvrir les SSD internes ?' \
    'Human use of attached USB peripherals; enumeration alone does not validate functionality or every USB port'
}

live_suspend_check() {
  local attempt observed started journal='' state
  attempt="$(live_manual_answer suspend_begin 'Essai facultatif : voulez-vous effectuer maintenant UNE veille/reprise depuis le menu GNOME ?')"
  if [[ "$attempt" != PASS ]]; then
    emit NOT_TESTED suspend_resume 'Single Live suspend/resume not attempted; installed-system suspend remains NOT_CERTIFIED' manual-and-kernel
    return
  fi
  started="$(date +%s)"
  printf '%s\n' 'Utilisez le menu GNOME pour mettre en veille, reveillez le PC, puis verifiez image, clavier et connexion avant de repondre. Le script ne declenche aucune veille.' >&2
  observed="$(live_manual_answer suspend_observation 'Apres cette veille, le bureau et les peripheriques utilises sont-ils revenus sans intervention corrective ?')"
  if command -v journalctl >/dev/null 2>&1; then journal="$(journalctl -k -b --since "@$started" --no-pager 2>/dev/null || true)"; fi
  state="$(live_suspend_cycle_status "$observed" "$journal")"
  emit "$state" suspend_resume "Human observation=$observed; PASS also requires ordered kernel suspend-entry/resume-exit markers from this attempt; one Live cycle only" manual-and-kernel
}

live_preflight_main() {
  case "${1:-}" in
    --help)
      echo 'Usage: bash diagnostics/live-preflight.sh [--help|--catalog]'
      echo 'Native Fedora 45 Live TSV observations only; no SSD writes, installs or automatic suspension.'
      return 0 ;;
    --catalog) printf 'CHECK\tREQUIREMENT\tEVIDENCE\n'; live_check_catalog; return 0 ;;
    '') [[ $# == 0 ]] || return 2 ;;
    *) echo 'Usage: bash diagnostics/live-preflight.sh [--help|--catalog]' >&2; return 2 ;;
  esac
  if (( EUID == 0 )); then echo 'REFUSED: run as an unprivileged Live session user.' >&2; return 2; fi
  [[ -r /etc/os-release ]] || { echo 'REFUSED: cannot identify operating system.' >&2; return 2; }
  # Independent of the production profile: pending may be observed.
  source /etc/os-release
  [[ "${ID:-}" == fedora ]] || { echo 'REFUSED: Fedora Live environment required.' >&2; return 2; }
  local cmdline
  cmdline="$(cat /proc/cmdline 2>/dev/null || true)"
  if [[ "$cmdline" != *rd.live.image* && "$cmdline" != *root=live:* && ! -d /run/initramfs/live ]]; then
    echo 'REFUSED: no evidence of a Live environment; never run this on an installed host.' >&2; return 2
  fi
  live_report_init
  live_identity_checks
  live_display_checks
  live_network_checks
  live_peripheral_checks
  live_suspend_check
  live_report_finish
}

# Sourceable for captured-command fixtures; no fake-Live switch exists.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then live_preflight_main "$@"; fi
