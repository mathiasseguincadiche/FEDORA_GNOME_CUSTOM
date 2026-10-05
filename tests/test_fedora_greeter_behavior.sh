#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=.github/scripts/fedora-greeter-ready.sh
source "$ROOT/.github/scripts/fedora-greeter-ready.sh"
step=0
bus_ready=true
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
sudo() { (( step >= 4 )) && "$bus_ready"; }
sleep() { ((step+=1)); }
fedora_lab_wait_greeter
[[ "$step" == 4 ]]
step=0
bus_ready=false
if fedora_lab_wait_greeter >/dev/null 2>&1; then
  echo 'greeter without a ready GNOME bus was accepted' >&2; exit 1
fi
[[ "$step" == 90 ]]
guest="$(cat "$ROOT/.github/scripts/fedora-gnome-guest.sh")"
python3 - "$guest" <<'PY'
import sys
section=sys.argv[1].split("  end-session)",1)[1].split("  session)",1)[0]
assert section.index("gnome-session-quit --logout") < section.index("fedora_lab_wait_greeter") < section.index("systemctl stop gdm") < section.index("journal_health 0")
assert "reset-failed" not in section
print("Fedora greeter synchronization: PASS (scope/process/bus observed; timeout blocks)")
PY
