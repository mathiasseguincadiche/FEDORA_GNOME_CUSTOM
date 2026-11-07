#!/usr/bin/env bash
# Operator logging must remain understandable without suppressing raw evidence.
# Everything runs in an isolated temporary directory; no Fedora mutation.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
fail() { printf 'operator logging: FAIL: %s\n' "$*" >&2; exit 1; }

REPO_ROOT="$tmp/fixture"
mkdir -p "$REPO_ROOT"
RUN_ID=20261107T123000000000000Z-12345
source "$ROOT/lib/logging.sh"
source "$ROOT/lib/ui.sh"
source "$ROOT/lib/control_center.sh"
logging_init

[[ "$(stat -c %a "$LOG_DIR")" == 700 ]] || fail 'run directory must be private'
[[ "$(stat -c %a "$MAIN_LOG")" == 600 ]] || fail 'main.log must be private'
[[ "$(stat -c %a "$MODULE_LOG")" == 600 ]] || fail 'modules.log must be private'

# Display output stays compatible; the separate operator log is timestamped.
[[ "$(ui_check WARN 'Kernel update' 'reportée, réessayer plus tard')" == '[WARN] Kernel update                reportée, réessayer plus tard' ]] \
  || fail 'the user-facing check format changed'
ui_summary 'MISE À JOUR REPORTÉE' 'Vérifier la cible plus tard' "$REPO_ROOT/report" "$LOG_DIR" > /dev/null
[[ "$(stat -c %a "$LOG_DIR/operator.log")" == 600 ]] || fail 'operator log must be private'
grep -Eq '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \[WARN\] \[OPERATOR\] Kernel update — reportée, réessayer plus tard$' \
  "$LOG_DIR/operator.log" || fail 'operator check not timestamped'
grep -Fq 'Étape suivante : Vérifier la cible plus tard' "$LOG_DIR/operator.log" || fail 'summary not retained'
cc_result 42 > "$tmp/menu-failure"
grep -Fq 'dernier journal utile' "$tmp/menu-failure" || fail 'menu failure did not provide next steps'
grep -Fq 'code rc=42' "$LOG_DIR/operator.log" || fail 'menu failure is missing from the operator journal'
cc_clear() { :; }
cc_header() { :; }
cc_section() { :; }
cc_pause() { :; }
before_view="$(wc -l < "$LOG_DIR/operator.log")"
cc_view_latest_log > "$tmp/menu-log-view"
[[ "$(wc -l < "$LOG_DIR/operator.log")" == "$before_view" ]] || fail 'viewing logs created a misleading new event'
grep -Fq 'code rc=42' "$tmp/menu-log-view" || fail 'menu log viewer hid the current failure'

# Reinitializing the same inherited run never truncates earlier evidence.
previous_count="$(wc -l < "$LOG_DIR/operator.log")"
logging_init
[[ "$(wc -l < "$LOG_DIR/operator.log")" == "$previous_count" ]] || fail 'nested initialization changed operator evidence'

# A menu session with useful events must display its own current log, whereas
# a fresh CLI `logs tail` command must skip its own empty bootstrap run.
result="$(cc_tail_latest_log)"
[[ "$result" == *'reportée, réessayer plus tard'* ]] || fail 'active interactive evidence is missing'
RUN_ID=20261107T123100000000000Z-12346
logging_init
previous=20261107T123050000000000Z-101
empty=20261107T123055000000000Z-102
mkdir -p "$LOG_ROOT/$previous" "$LOG_ROOT/$empty"
printf '%s\n' 'événement technique précédent' > "$LOG_ROOT/$previous/main.log"
printf '%s\n' 'explication opérateur précédente' > "$LOG_ROOT/$previous/operator.log"
result="$(cc_tail_latest_log)"
[[ "$result" == *'explication opérateur précédente'* ]] || fail 'previous operator log is missing'
[[ "$result" == *'événement technique précédent'* ]] || fail 'previous technical log is missing'
[[ "$result" != *"$RUN_ID"* ]] || fail 'empty current run was mistakenly selected'

# A previous run with only raw module output is still discoverable.
previous_module=20261107T123060000000000Z-103
mkdir -p "$LOG_ROOT/$previous_module"
printf '%s\n' 'trace brute du module' > "$LOG_ROOT/$previous_module/modules.log"
result="$(cc_tail_latest_log)"
[[ "$result" == *'trace brute du module'* ]] || fail 'module-only run was ignored'

printf 'operator logging: PASS (timestamps, privacy, preserved output, last useful run)\n'
