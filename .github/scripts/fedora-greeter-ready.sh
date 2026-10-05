#!/usr/bin/env bash
# Read-only synchronization for the disposable GNOME lab after normal logout.
# GDM creates a greeter asynchronously; stopping it before logind attaches
# its worker to the scope can fail with Result=resources.
fedora_lab_wait_greeter() {
  local sid uid
  for _ in {1..90}; do
    while IFS= read -r sid; do
      [[ "$sid" =~ ^[a-zA-Z0-9]+$ ]] || continue
      [[ "$(loginctl show-session "$sid" -p Class --value)" == greeter &&
         "$(loginctl show-session "$sid" -p Type --value)" == wayland &&
         "$(loginctl show-session "$sid" -p Active --value)" == yes ]] || continue
      systemctl is-active --quiet "session-$sid.scope" || continue
      uid="$(loginctl show-session "$sid" -p User --value)"
      [[ "$uid" =~ ^[0-9]+$ ]] || continue
      pgrep -u "$uid" -x gnome-shell >/dev/null || continue
      if sudo -u "#$uid" env XDG_RUNTIME_DIR="/run/user/$uid" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
          gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
          --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        printf 'Greeter ready: session=%s scope=active GNOME bus=ready\n' "$sid"
        return 0
      fi
    done < <(loginctl list-sessions --no-legend | awk '{print $1}')
    sleep 1
  done
  echo 'GDM greeter did not become ready after normal logout; refusing a raced stop.' >&2
  return 1
}
