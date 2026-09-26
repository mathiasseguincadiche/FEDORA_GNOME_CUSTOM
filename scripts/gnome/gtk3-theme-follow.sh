#!/usr/bin/env bash
# Keep legacy GTK3 applications in sync with the GNOME light/dark switch.
# libadwaita apps follow org.gnome.desktop.interface color-scheme natively;
# GTK3 apps only read gtk-theme, so this watcher mirrors one into the other.
set -Eeuo pipefail

light="${POLISH_GTK3_THEME_LIGHT:-adw-gtk3}"
dark="${POLISH_GTK3_THEME_DARK:-adw-gtk3-dark}"
schema='org.gnome.desktop.interface'

theme_for_scheme() {
  case "$1" in
    *prefer-dark*) printf '%s\n' "$dark" ;;
    *) printf '%s\n' "$light" ;;
  esac
}

sync_once() {
  local scheme wanted current
  scheme="$(gsettings get "$schema" color-scheme 2>/dev/null || printf 'default')"
  wanted="$(theme_for_scheme "$scheme")"
  current="$(gsettings get "$schema" gtk-theme 2>/dev/null || true)"
  [[ "$current" == "'$wanted'" ]] || gsettings set "$schema" gtk-theme "$wanted"
}

case "${1:-watch}" in
  once) sync_once ;;
  theme-for) theme_for_scheme "${2:-default}" ;;
  watch)
    sync_once
    gsettings monitor "$schema" color-scheme | while read -r _; do sync_once; done
    ;;
  *) echo 'Usage: gtk3-theme-follow.sh [watch|once|theme-for <color-scheme>]' >&2; exit 2 ;;
esac
