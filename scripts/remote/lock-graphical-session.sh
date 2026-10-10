#!/usr/bin/env bash
# A systemd user service often has no XDG_SESSION_ID. Resolve the active local
# Wayland session by UID and verify loginctl actually reports it locked.
set -Eeuo pipefail
uid="$(id -u)"
while read -r sid _; do
  [[ "$sid" =~ ^[a-zA-Z0-9]+$ ]] || continue
  [[ "$(loginctl show-session "$sid" -p User --value 2>/dev/null || true)" == "$uid" ]] || continue
  [[ "$(loginctl show-session "$sid" -p Class --value 2>/dev/null || true)" == user ]] || continue
  [[ "$(loginctl show-session "$sid" -p Remote --value 2>/dev/null || true)" == no ]] || continue
  [[ "$(loginctl show-session "$sid" -p Active --value 2>/dev/null || true)" == yes ]] || continue
  [[ "$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)" == wayland ]] || continue
  loginctl lock-session "$sid"
  for ((i=0; i<15; i++)); do
    [[ "$(loginctl show-session "$sid" -p LockedHint --value 2>/dev/null || true)" == yes ]] && exit 0
    sleep 0.3
  done
  echo "Session $sid: loginctl did not confirm LockedHint=yes" >&2
  exit 1
done < <(loginctl list-sessions --no-legend)
echo 'No active local Wayland session is available for locking.' >&2
exit 1
