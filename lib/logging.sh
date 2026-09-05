#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

logging_init() {
  RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
  LOG_ROOT="$REPO_ROOT/logs"
  REPORT_ROOT="$REPO_ROOT/reports"
  STATE_ROOT="$REPO_ROOT/state"
  LOG_DIR="$LOG_ROOT/$RUN_ID"
  mkdir -p "$LOG_DIR" "$REPORT_ROOT" "$STATE_ROOT" "$STATE_ROOT/releases"
  MAIN_LOG="$LOG_DIR/main.log"
  MODULE_LOG="$LOG_DIR/modules.log"
  : > "$MAIN_LOG"
  : > "$MODULE_LOG"
  export RUN_ID LOG_ROOT REPORT_ROOT STATE_ROOT LOG_DIR MAIN_LOG MODULE_LOG
}

_log() {
  local level="$1" scope="$2"; shift 2
  printf '%s [%s] [%s] %s\n' "$(date -u +%FT%TZ)" "$level" "$scope" "$*" | tee -a "$MAIN_LOG" >&2
}
log_info() { _log INFO "$@"; }
log_warn() { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }
