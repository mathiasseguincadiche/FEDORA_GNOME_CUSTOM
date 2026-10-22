#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=.github/scripts/fedora-greeter-ready.sh
source "$ROOT/.github/scripts/fedora-greeter-ready.sh"
step=0
bus_ready=true
usb_ready=true
power_owner_ready=true
power_property_ready=true
power_property_calls=0
loginctl() {
  if [[ "$1" == list-sessions ]]; then
    if (( step >= 1 )); then echo 'c1 60578 gdm-greeter seat0 tty1'; fi
    return 0
  fi
  case "$4" in
    Class) echo greeter ;; Type) echo wayland ;; Active) echo yes ;; User) echo 60578 ;;
  esac
}
systemctl() { (( step >= 2 )); }
pgrep() { (( step >= 3 )); }
sudo() {
  if [[ "$*" == *org.freedesktop.DBus.NameHasOwner* ]]; then
    case "${!#}" in
      org.gnome.SettingsDaemon.UsbProtection)
        if (( step >= 5 )) && "$usb_ready"; then echo '(true,)'; else echo '(false,)'; fi ;;
      org.gnome.SettingsDaemon.Power)
        if (( step >= 6 )) && "$power_owner_ready"; then echo '(true,)'; else echo '(false,)'; fi ;;
      *) return 2 ;;
    esac
  elif [[ "$*" == *org.freedesktop.DBus.Properties.Get* ]]; then
    [[ "$*" == *'--timeout=2 --dest org.gnome.SettingsDaemon.Power --object-path /org/gnome/SettingsDaemon/Power --method org.freedesktop.DBus.Properties.Get org.gnome.SettingsDaemon.Power.Keyboard Brightness' ]] || return 2
    ((power_property_calls+=1))
    (( step >= 7 )) && "$power_property_ready"
  else
    (( step >= 4 )) && "$bus_ready"
  fi
}
sleep() { ((step+=1)); }
fedora_lab_wait_greeter
[[ "$step" == 7 && "$power_property_calls" == 2 ]]
step=0
bus_ready=false
if fedora_lab_wait_greeter >/dev/null 2>&1; then
  echo 'greeter without a ready GNOME bus was accepted' >&2; exit 1
fi
[[ "$step" == 90 ]]
step=0
bus_ready=true
usb_ready=true
power_owner_ready=false
power_property_calls=0
if fedora_lab_wait_greeter >/dev/null 2>&1; then
  echo 'greeter with unowned Power bus was accepted' >&2; exit 1
fi
[[ "$step" == 90 && "$power_property_calls" == 0 ]]
step=0
power_owner_ready=true
power_property_ready=false
if fedora_lab_wait_greeter >/dev/null 2>&1; then
  echo 'greeter with owned Power name but unresponsive property handler was accepted' >&2; exit 1
fi
[[ "$step" == 90 && "$power_property_calls" -gt 0 ]]
step=0
bus_ready=true
usb_ready=false
power_property_ready=true
power_property_calls=0
if fedora_lab_wait_greeter >/dev/null 2>&1; then
  echo 'greeter with unregistered USB protection was accepted' >&2; exit 1
fi
[[ "$step" == 90 && "$power_property_calls" == 0 ]]
guest="$(cat "$ROOT/.github/scripts/fedora-gnome-guest.sh")"
python3 - "$guest" <<'PY'
import sys
section=sys.argv[1].split("  end-session)",1)[1].split("  session)",1)[0]
assert section.index("gnome-session-quit --logout") < section.index("fedora_lab_wait_greeter") < section.index("systemctl stop gdm") < section.index("journal_health 0")
assert "reset-failed" not in section
print("Fedora greeter synchronization: PASS (scope/process/Shell/USB and Power property observed; timeout blocks)")
PY
