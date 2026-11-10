#!/usr/bin/env bash
# Isolated, destructive-in-fixture-only regression for the manual retention path.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
fixture="$tmp/retention fixture"
mkdir -p "$fixture/scripts/maintenance" "$fixture/lib" "$fixture/config" \
  "$fixture/logs/incidents" "$fixture/reports"
cp "$ROOT/scripts/maintenance/prune-project-artifacts.sh" "$fixture/scripts/maintenance/"
cp "$ROOT/config/operator-retention.policy" "$fixture/config/"
cat > "$fixture/lib/bootstrap.sh" <<'BOOT'
engine_bootstrap() {
  LOG_ROOT="$REPO_ROOT/logs"
  REPORT_ROOT="$REPO_ROOT/reports"
  LOG_DIR="$LOG_ROOT/current"
  EXIT_CONFIG_FAILED=60
  EXIT_SECURITY_BLOCK=50
  EXIT_USAGE=2
}
BOOT

open_run=20260601T010203000000000Z-101
resolved_run=20260601T010203000000000Z-102
failed_run=20260601T010203000000000Z-103
clean_run=20260601T010203000000000Z-104
error_run=20260601T010203000000000Z-105
for run in "$open_run" "$resolved_run" "$failed_run" "$clean_run" "$error_run"; do
  mkdir -p "$fixture/logs/$run"
  printf '%s\n' '[INFO] [SYSTEM] completed' > "$fixture/logs/$run/main.log"
  printf 'run_id=%s\noverall=PASS\n' "$run" > "$fixture/reports/run-$run.txt"
  printf '{"run_id":"%s","overall":"PASS"}\n' "$run" > "$fixture/reports/run-$run.json"
  touch -d '200 days ago' "$fixture/logs/$run" "$fixture/reports/run-$run.txt" "$fixture/reports/run-$run.json"
done
printf '{"status":"open"}\n' > "$fixture/logs/incidents/$open_run.json"
printf '{"status":"resolved","resolution":"verified"}\n' > "$fixture/logs/incidents/$resolved_run.json"
printf '{"run_id":"%s","overall":"FAIL"}\n' "$failed_run" > "$fixture/reports/run-$failed_run.json"
printf '%s\n' 'overall=FAIL' > "$fixture/reports/run-$failed_run.txt"
printf '%s\n' '[ERROR] [SYSTEM] failed' > "$fixture/logs/$error_run/main.log"
touch -d '200 days ago' "$fixture/reports/run-$failed_run.json" "$fixture/reports/run-$failed_run.txt"

bash "$fixture/scripts/maintenance/prune-project-artifacts.sh" --check > "$tmp/check"
[[ -d "$fixture/logs/$clean_run" && -f "$fixture/reports/run-$clean_run.json" ]]
grep -Fq 'preserved (incident/failed run)' "$tmp/check"
bash "$fixture/scripts/maintenance/prune-project-artifacts.sh" --apply > "$tmp/apply"

[[ -d "$fixture/logs/$open_run" && -d "$fixture/logs/$error_run" ]]
[[ -f "$fixture/reports/run-$open_run.json" && -f "$fixture/reports/run-$open_run.txt" ]]
[[ -f "$fixture/reports/run-$failed_run.json" && -f "$fixture/reports/run-$failed_run.txt" ]]
[[ ! -e "$fixture/logs/$clean_run" && ! -e "$fixture/reports/run-$clean_run.json" ]]
[[ ! -e "$fixture/reports/run-$clean_run.txt" && ! -e "$fixture/reports/run-$resolved_run.json" ]]
[[ -f "$fixture/logs/incidents/$open_run.json" ]]

# The optional timer is intentionally disabled by default, and its installed
# service is path-independent. Test installation as an unprivileged CI user.
if (( EUID != 0 )); then
  timer_root="$tmp/renamed clone with spaces"
  mkdir -p "$timer_root/scripts/maintenance" "$timer_root/systemd/user" "$timer_root/config" "$tmp/bin" "$tmp/home"
  cp "$ROOT/scripts/maintenance/install-weekly-log-cleanup.sh" "$timer_root/scripts/maintenance/"
  cp "$ROOT/scripts/maintenance/weekly-log-cleanup.py" "$timer_root/scripts/maintenance/"
  cp "$ROOT/systemd/user/fgc-weekly-log-cleanup.service" "$timer_root/systemd/user/"
  cp "$ROOT/systemd/user/fgc-weekly-log-cleanup.timer" "$timer_root/systemd/user/"
  cp "$ROOT/config/operator-retention.policy" "$timer_root/config/"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$TEST_SYSTEMCTL_CALLS"\n' > "$tmp/bin/systemctl"
  chmod +x "$tmp/bin/systemctl"
  HOME="$tmp/home" PATH="$tmp/bin:$PATH" TEST_SYSTEMCTL_CALLS="$tmp/systemctl-calls" \
    bash "$timer_root/scripts/maintenance/install-weekly-log-cleanup.sh" > "$tmp/installer"
  [[ -x "$tmp/home/.local/libexec/fgc-weekly-log-cleanup" ]]
  grep -Fq 'renamed\ clone\ with\ spaces/scripts/maintenance/weekly-log-cleanup.py' "$tmp/home/.local/libexec/fgc-weekly-log-cleanup"
  bash -n "$tmp/home/.local/libexec/fgc-weekly-log-cleanup"
  grep -Fq 'daemon-reload' "$tmp/systemctl-calls"
  ! grep -Eq 'enable|start' "$tmp/systemctl-calls"
  grep -Fq 'ExecStart=%h/.local/libexec/fgc-weekly-log-cleanup' "$tmp/home/.config/systemd/user/fgc-weekly-log-cleanup.service"
fi
printf '%s\n' 'operator retention behavior: PASS'
