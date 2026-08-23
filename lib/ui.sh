#!/usr/bin/env bash

ui_banner() { printf '\n==== %s :: %s ====\n' "$1" "$2"; }
ui_meta() { printf '%-22s %s\n' "$1:" "$2"; }
ui_check() { printf '[%-4s] %-28s %s\n' "$1" "$2" "${3:-}"; }
ui_info() { printf '[INFO] %s\n' "$*"; }
ui_warn() { printf '[WARN] %s\n' "$*"; }
ui_error() { printf '[KO]   %s\n' "$*" >&2; }
ui_summary() {
  printf '\nVERDICT: %s\nNEXT STEP: %s\nREPORT: %s\nLOGS: %s\n' "$1" "$2" "$3" "$4"
}
