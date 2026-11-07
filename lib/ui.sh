#!/usr/bin/env bash
# Console output helpers shared by the engines and doctors (banner, check line, summary).

# The operator journal records project-authored verdicts separately from raw
# technical outputs. It never replaces main.log, modules.log or the DNF5 log.
ui_record() {
  local level="$1" subject="$2" detail="${3:-}" target
  [[ -n "${LOG_DIR:-}" && -d "$LOG_DIR" ]] || return 0
  target="$LOG_DIR/operator.log"
  [[ ! -L "$target" ]] || return 0
  subject="${subject//$'\n'/ }"
  detail="${detail//$'\n'/ }"
  (
    umask 077
    printf '%s [%s] [OPERATOR] %s%s\n' "$(date -u +%FT%TZ)" "$level" "$subject" "${detail:+ — $detail}" >> "$target"
  ) || return 0
}

ui_banner() {
  printf '\n==== %s :: %s ====\n' "$1" "$2"
  ui_record INFO "$1" "$2"
}
ui_meta() { printf '%-22s %s\n' "$1:" "$2"; }
ui_check() {
  printf '[%-4s] %-28s %s\n' "$1" "$2" "${3:-}"
  ui_record "$1" "$2" "${3:-}"
}
ui_info() { printf '[INFO] %s\n' "$*"; ui_record INFO 'Information' "$*"; }
ui_warn() { printf '[WARN] %s\n' "$*"; ui_record WARN 'Avertissement' "$*"; }
ui_error() { printf '[KO]   %s\n' "$*" >&2; ui_record KO 'Échec' "$*"; }
ui_summary() {
  printf '\nVERDICT: %s\nNEXT STEP: %s\nREPORT: %s\nLOGS: %s\n' "$1" "$2" "$3" "$4"
  ui_record VERDICT "$1" "Étape suivante : $2 | Rapport : $3"
}
