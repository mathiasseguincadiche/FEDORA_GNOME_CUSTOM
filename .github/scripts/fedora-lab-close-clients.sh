#!/usr/bin/env bash
# Disposable lab only. as_user is supplied by the guarded guest entrypoint.
fedora_lab_close_clients() {
  local lab_uid="$1" client rc remaining
  # Nautilus is a D-Bus single-instance application: --new-window may forward
  # to an existing FileManager1 process and let our transient launcher exit.
  # Stopping that launcher does not close the actual application.
  as_user timeout --signal=TERM --kill-after=5s 20s nautilus --quit || return
  for _ in {1..30}; do
    remaining=false
    for client in nautilus ptyxis; do
      if pgrep -u "$lab_uid" -x "$client" >/dev/null; then
        remaining=true
      else
        rc=$?
        if (( rc != 1 )); then
          echo "Cannot verify CI desktop client termination: $client (pgrep=$rc)" >&2
          return 1
        fi
      fi
    done
    if [[ "$remaining" == false ]]; then
      echo 'CI desktop clients closed: Nautilus and Ptyxis processes absent'
      return 0
    fi
    sleep 1
  done
  echo 'CI desktop client still running; refusing a raced GNOME logout' >&2
  return 1
}
