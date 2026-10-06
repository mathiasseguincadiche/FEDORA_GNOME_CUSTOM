#!/usr/bin/env bash
# Borg warnings policy (real Borg + exact Borg log lines):
# - daily archives tolerate ONLY "file changed while we backed it up";
# - any other warning, and any warning on pre-APPLY/full, refuses the archive;
# - refused archives stay as fgc-pending-* and retention bounds their number.
# shellcheck disable=SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v borg >/dev/null || { echo 'borg required' >&2; exit 20; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "borg daily warnings behavior: FAIL: $*" >&2; exit 1; }
export BORG_BASE_DIR="$tmp/base"
# shellcheck source=lib/backup_runtime.sh
source "$ROOT/lib/backup_runtime.sh"

# 1. Classifier, fed with the exact line Borg 1.2 emits for a live file.
changed='{"type": "log_message", "time": 1791312124.74, "message": "src/big.bin: file changed while we backed it up", "levelname": "WARNING", "name": "borg.archiver"}'
denied='{"type": "log_message", "time": 1791312124.74, "message": "src/key: [Errno 13] Permission denied", "levelname": "WARNING", "name": "borg.archiver"}'
printf '%s\n%s\n' "$changed" "$changed" > "$tmp/changed.log"
printf '%s\n%s\n' "$changed" "$denied" > "$tmp/mixed.log"
: > "$tmp/clean.log"
[[ "$(backup_engine_tolerated_changes daily 1 "$tmp/changed.log")" == 2 ]] || fail 'live-file warnings refused for daily'
[[ "$(backup_engine_tolerated_changes daily 0 "$tmp/clean.log")" == 0 ]] || fail 'clean daily not accepted'
for args in "preapply 1 changed" "full 1 changed" "daily 1 mixed" "daily 1 clean" "daily 2 changed"; do
  read -r kind rc log <<<"$args"
  if backup_engine_tolerated_changes "$kind" "$rc" "$tmp/$log.log" >/dev/null; then fail "accepted: $args"; fi
done

# 2. Real Borg: a non-tolerated warning refuses the daily archive.
backup_engine_env "$tmp/repo"
backup_engine_init >/dev/null
mkdir -p "$tmp/src" && echo data > "$tmp/src/file"
rc=0; backup_engine_create daily -- "$tmp/src" "$tmp/does-not-exist" >/dev/null 2>"$tmp/err" || rc=$?
((rc != 0)) || fail 'daily archive with a missing source was certified'
grep -Fq 'refused certification' "$tmp/err" || fail 'refusal not explained'
grep -Fq 'borg WARNING' "$tmp/err" || fail 'Borg warning not shown to the user'
[[ "$(backup_engine_pending_count)" == 1 ]] || fail 'refused archive not kept as fgc-pending-*'
if borg list --short --glob-archives 'fgc-daily-*' | grep -q .; then fail 'refused archive promoted to fgc-daily-*'; fi

# 3. A clean daily archive still works and reports zero changed files.
report="$tmp/warnings"
read -r name id < <(BACKUP_ENGINE_WARNINGS_REPORT="$report" backup_engine_create daily -- "$tmp/src")
[[ "$name" == fgc-daily-* && "$id" =~ ^[0-9a-f]{64}$ ]] || fail 'clean daily archive not created'
grep -Fxq 'files_changed_during_backup=0' "$report" || fail 'warning report missing'

# 4. Refused archives are bounded by retention, newest kept.
for _ in 1 2 3 4; do backup_engine_create daily -- "$tmp/src" "$tmp/does-not-exist" >/dev/null 2>&1 || true; done
[[ "$(backup_engine_pending_count)" == 5 ]] || fail "expected 5 pending archives, got $(backup_engine_pending_count)"
newest="$(borg list --short --glob-archives 'fgc-pending-*' | sort | tail -n1)"
BACKUP_KEEP_PENDING=3 backup_engine_prune_pending >/dev/null
[[ "$(backup_engine_pending_count)" == 3 ]] || fail 'pending archives not bounded by retention'
borg list --short --glob-archives 'fgc-pending-*' | grep -Fxq "$newest" || fail 'newest refused archive was pruned'
borg list --short | grep -Fxq "$name" || fail 'pending retention touched a certified daily archive'
echo 'borg daily warnings behavior: PASS'
