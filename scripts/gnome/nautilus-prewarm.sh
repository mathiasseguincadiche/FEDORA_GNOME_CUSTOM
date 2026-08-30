#!/usr/bin/env bash
set -Eeuo pipefail
# Prewarm only non-visual dependencies. Never start Nautilus here: the first Files click must remain a true cold Nautilus launch.
if command -v gdbus >/dev/null 2>&1; then
  gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1 || true
fi
if command -v gio >/dev/null 2>&1; then
  gio mime inode/directory >/dev/null 2>&1 || true
  gio mime application/octet-stream >/dev/null 2>&1 || true
fi
if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -Fxq org.gnome.nautilus.preferences; then
  gsettings get org.gnome.nautilus.preferences show-image-thumbnails >/dev/null 2>&1 || true
fi
exit 0
