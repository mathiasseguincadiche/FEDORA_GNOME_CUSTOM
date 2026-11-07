#!/usr/bin/env bash
# Retention of logs/ and reports/ (./control.sh logs retention|prune): --check lists what
# would go, --apply deletes it. state/ and Golden evidence are never touched.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

POLICY="$REPO_ROOT/config/operator-retention.policy"

usage() {
  cat <<'EOF'
Usage: prune-project-artifacts.sh [--check|--apply]

  --check  Show transient artifacts older than the versioned retention policy.
  --apply  Delete only matching logs/ and reports/ artifacts.

state/ and state/releases/ are never pruned by this script.
EOF
}

policy_value() {
  local key="$1"
  awk -F= -v wanted="$key" '$1==wanted {print $2; exit}' "$POLICY"
}

require_positive_integer() {
  local label="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "Invalid $label in $POLICY: ${value:-missing}" >&2
    exit "$EXIT_CONFIG_FAILED"
  }
}

[[ -r "$POLICY" ]] || { echo "Missing retention policy: $POLICY" >&2; exit "$EXIT_CONFIG_FAILED"; }

logs_days="$(policy_value logs_days)"
reports_days="$(policy_value reports_days)"
preserve_state="$(policy_value preserve_state)"
preserve_releases="$(policy_value preserve_releases)"

require_positive_integer logs_days "$logs_days"
require_positive_integer reports_days "$reports_days"
[[ "$preserve_state" == true ]] || { echo 'Retention policy must preserve state/' >&2; exit "$EXIT_SECURITY_BLOCK"; }
[[ "$preserve_releases" == true ]] || { echo 'Retention policy must preserve Golden releases' >&2; exit "$EXIT_SECURITY_BLOCK"; }

mode="${1:---check}"
case "$mode" in
  --check|--apply) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

mapfile -d '' old_logs < <(
  # The incident store is permanent evidence, never a transient run directory.
  find "$LOG_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$logs_days" \
    ! -path "$LOG_DIR" ! -name incidents -print0 2>/dev/null || true
)
mapfile -d '' old_reports < <(
  find "$REPORT_ROOT" -mindepth 1 -maxdepth 1 -type f -mtime "+$reports_days" -print0 2>/dev/null || true
)

printf 'Retention policy: logs=%s days, reports=%s days\n' "$logs_days" "$reports_days"
printf 'Golden evidence: state/=preserved, state/releases/=preserved\n'
printf 'Old log runs: %d\n' "${#old_logs[@]}"
printf 'Old transient reports: %d\n' "${#old_reports[@]}"

safe_old_logs=()
for path in "${old_logs[@]}"; do
  run="${path##*/}"
  # An open/unknown incident must never be deleted by a separate retention
  # engine. Resolved incidents are handled by the weekly lifecycle as well.
  if [[ -e "$LOG_ROOT/incidents/$run.json" || -L "$LOG_ROOT/incidents/$run.json" ]]; then
    printf '  preserved (incident): %s\n' "$path"
    continue
  fi
  # If the weekly incident scanner has not run, preserve error-bearing logs.
  # Only regular *.log files are inspected. Unexpected files/types fail closed.
  unexpected="$(find "$path" -mindepth 1 -maxdepth 1 \( ! -type f -o ! -name '*.log' \) -print -quit 2>/dev/null)"
  if [[ -n "$unexpected" ]]; then
    printf '  preserved (unexpected content): %s\n' "$path"
    continue
  fi
  log_files=("$path"/*.log)
  if [[ -e "${log_files[0]}" ]]; then
    if grep -Eiq '\[(ERROR|KO|FAIL|FATAL)\]|TRACEBACK|SECURITY BLOCK|FAILED' "${log_files[@]}"; then
      printf '  preserved (unresolved error): %s\n' "$path"
      continue
    else
      grep_rc=$?
      if ((grep_rc != 1)); then
        printf '  preserved (unreadable log): %s\n' "$path"
        continue
      fi
    fi
  fi
  safe_old_logs+=("$path")
  printf '  log: %s\n' "$path"
done
for path in "${old_reports[@]}"; do printf '  report: %s\n' "$path"; done

if [[ "$mode" == --check ]]; then
  exit 0
fi

for path in "${safe_old_logs[@]}"; do
  [[ "$path" == "$LOG_ROOT"/* ]] || { echo "Refusing unexpected log path: $path" >&2; exit "$EXIT_SECURITY_BLOCK"; }
  rm -rf -- "$path"
done
for path in "${old_reports[@]}"; do
  [[ "$path" == "$REPORT_ROOT"/* ]] || { echo "Refusing unexpected report path: $path" >&2; exit "$EXIT_SECURITY_BLOCK"; }
  rm -f -- "$path"
done

printf 'Pruned %d safe old log runs and %d old transient reports.\n' "${#safe_old_logs[@]}" "${#old_reports[@]}"
