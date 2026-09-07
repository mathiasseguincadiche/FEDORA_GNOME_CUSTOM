#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
scope="${1:-full}"
case "$scope" in gate2|full) ;; *) echo 'Usage: configure-default-apps.sh [gate2|full]' >&2; exit "$EXIT_USAGE";; esac
command -v xdg-mime >/dev/null 2>&1 || { ui_error 'xdg-mime is required'; exit "$EXIT_PRECHECK_FAILED"; }

set_default(){ local desktop="$1"; shift; local mime
  [[ -r "/usr/share/applications/$desktop" || -r "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$desktop" ]] || { ui_error "Desktop entry missing: $desktop"; return "$EXIT_PRECHECK_FAILED"; }
  for mime in "$@"; do xdg-mime default "$desktop" "$mime" || return "$EXIT_APPLY_FAILED"; done
}

set_default "${DEFAULT_FILE_MANAGER_DESKTOP:-org.gnome.Nautilus.desktop}" inode/directory
set_default "${DEFAULT_PDF_DESKTOP:-org.gnome.Papers.desktop}" application/pdf
set_default "${DEFAULT_IMAGE_DESKTOP:-org.gnome.Loupe.desktop}" image/jpeg image/png image/webp image/gif
set_default "${DEFAULT_TEXT_DESKTOP:-org.gnome.TextEditor.desktop}" text/plain
set_default "${DEFAULT_VIDEO_DESKTOP:-org.gnome.Showtime.desktop}" video/mp4 video/x-matroska video/webm
set_default "${DEFAULT_ARCHIVE_DESKTOP:-org.gnome.FileRoller.desktop}" application/zip application/x-tar application/x-compressed-tar
if [[ "$scope" == full ]]; then
  set_default "${DEFAULT_BROWSER_DESKTOP:-brave-browser.desktop}" text/html x-scheme-handler/http x-scheme-handler/https
fi
update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications" >/dev/null 2>&1 || true
