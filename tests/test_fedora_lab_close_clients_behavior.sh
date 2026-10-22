#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=.github/scripts/fedora-lab-close-clients.sh
source "$ROOT/.github/scripts/fedora-lab-close-clients.sh"
step=0
quit_requested=false
mode=delayed
as_user() {
  [[ "$*" == 'timeout --signal=TERM --kill-after=5s 20s gapplication action org.gnome.Nautilus quit' ]] || return 99
  quit_requested=true
  [[ "$mode" != quit-failure ]]
}
pgrep() {
  [[ "$1 $2 $3" == '-u 1000 -x' ]] || return 99
  case "$mode" in
    probe-failure) return 2 ;;
    stuck|quit-failure) return 0 ;;
    delayed)
      if [[ "$4" == nautilus ]] && (( step < 2 )); then return 0; fi
      if [[ "$4" == ptyxis ]] && (( step < 3 )); then return 0; fi
      return 1 ;;
    absent) return 1 ;;
    *) return 3 ;;
  esac
}
sleep() { ((step+=1)); }
# Regress the real failure: the launcher's inactive state says nothing about
# Nautilus. The helper must issue its supported quit request and observe exit.
fedora_lab_close_clients 1000
[[ "$quit_requested" == true && "$step" == 3 ]]
mode=absent; step=0; quit_requested=false
fedora_lab_close_clients 1000
[[ "$quit_requested" == false && "$step" == 0 ]]
for mode in stuck probe-failure quit-failure; do
  step=0; quit_requested=false
  if fedora_lab_close_clients 1000 >/dev/null 2>&1; then
    echo "Unsafe client close accepted: $mode" >&2; exit 1
  fi
  if [[ "$mode" == probe-failure ]]; then
    [[ "$quit_requested" == false ]]
  else
    [[ "$quit_requested" == true ]]
  fi
  if [[ "$mode" == stuck ]]; then [[ "$step" == 30 ]]; else [[ "$step" == 0 ]]; fi
done
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
guest=(Path(sys.argv[1])/'.github/scripts/fedora-gnome-guest.sh').read_text()
logout=guest.split('  end-session)',1)[1].split('  session)',1)[0]
assert logout.index('fedora_lab_close_clients "$LAB_UID"') < logout.index('gnome-session-quit --logout')
assert logout.index('gnome-session-quit --logout') < logout.index('journal_health 0')
assert 'reset-failed' not in logout
assert 'disable-user-extensions' not in logout
print('Fedora lab real client closure: PASS (delayed/absent/stuck/probe/quit failure)')
PY
