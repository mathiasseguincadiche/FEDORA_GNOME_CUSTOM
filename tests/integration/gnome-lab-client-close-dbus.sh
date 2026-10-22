#!/usr/bin/env bash
# Real GApplication/session-bus protocol fixture, not GNOME qualification.
set -Eeuo pipefail
[[ -e /.dockerenv || -e /run/.containerenv ]] || { echo 'Disposable container required' >&2; exit 50; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "${1:-}" != private-bus ]]; then
  exec dbus-run-session -- bash "$0" private-bus
fi
fixture="$(mktemp -d)"
fixture_pid=''
cleanup() {
  [[ -z "$fixture_pid" ]] || kill "$fixture_pid" 2>/dev/null || true
  rm -rf -- "$fixture"
}
trap cleanup EXIT
cat > "$fixture/app.py" <<'PY'
import ctypes
from pathlib import Path
import sys
from gi.repository import Gio

# Mimic Nautilus' exported action and twelve-second inactivity lifetime,
# without starting GTK, GNOME or any real file-manager process.
ctypes.CDLL(None).prctl(15, b"nautilus", 0, 0, 0)
app = Gio.Application(application_id="org.gnome.Nautilus", inactivity_timeout=12000)
def startup(application):
    application.hold()
    action = Gio.SimpleAction.new("quit", None)
    action.connect("activate", lambda *_: application.release())
    application.add_action(action)
    Path(sys.argv[1]).write_text("ready")
app.connect("startup", startup)
app.connect("activate", lambda *_: None)
app.run(["nautilus-protocol-fixture"])
PY
python3 "$fixture/app.py" "$fixture/ready" &
fixture_pid=$!
for _ in {1..100}; do
  [[ ! -s "$fixture/ready" ]] || break
  kill -0 "$fixture_pid"
  sleep 0.1
done
[[ -s "$fixture/ready" ]]
# shellcheck source=.github/scripts/fedora-lab-close-clients.sh
source "$ROOT/.github/scripts/fedora-lab-close-clients.sh"
as_user() { "$@"; }
fedora_lab_close_clients "$(id -u)"
wait "$fixture_pid"
fixture_pid=''
echo 'Real GApplication quit action: PASS (private D-Bus, no display, delayed process exit)'
