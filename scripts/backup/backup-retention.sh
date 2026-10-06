#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

strict=false
[[ "${1:-}" == --strict ]] && strict=true
[[ $# -le 1 ]] || { echo 'Usage: backup-retention.sh [--strict]' >&2; exit 2; }

if [[ -n "${FEDORA_GNOME_CUSTOM_RUNTIME_ROOT:-}" ]]; then
  helper="$FEDORA_GNOME_CUSTOM_RUNTIME_ROOT/lib/backup_runtime_bundle.sh"
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  helper="$REPO_ROOT/lib/backup_runtime_bundle.sh"
fi
[[ -r "$helper" ]] || { echo "Missing backup runtime helper: $helper" >&2; exit 20; }
# shellcheck disable=SC1090
source "$helper"
backup_runtime_bundle_init

skip_or_fail() {
  local reason="$1"
  printf 'utc=%s\nreason=%s\nruntime_sha=%s\n' "$(date -u +%FT%TZ)" "$reason" "$FEDORA_GNOME_CUSTOM_RUNTIME_SHA" > "$STATE_ROOT/last-retention-skipped"
  if $strict; then
    echo "Backup retention failed: $reason" >&2
    exit 20
  fi
  exit 0
}

repo="$(backup_runtime_resolve_repository 2>/dev/null || true)"
[[ -n "$repo" ]] || skip_or_fail repository-unavailable
backup_engine_require >/dev/null 2>&1 || skip_or_fail borg-unavailable
backup_engine_env "$repo"
backup_engine_repo_ready || skip_or_fail repository-unreachable

# One retention set per archive class (fgc-full-*, fgc-daily-*). Pre-APPLY
# archives are never pruned automatically: they are the rollback points.
for kind in full daily; do
  backup_engine_prune "$kind" || skip_or_fail "prune-$kind-failed"
done
# Failed-certification archives (fgc-pending-*): bounded, newest kept for review.
backup_engine_prune_pending || skip_or_fail prune-pending-failed
backup_engine_compact || skip_or_fail compact-failed

{
  printf 'utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'runtime_sha=%s\n' "$FEDORA_GNOME_CUSTOM_RUNTIME_SHA"
  printf 'repository=%s\n' "$repo"
  printf 'engine=borg\n'
  printf 'keep_daily=%s\n' "${BACKUP_KEEP_DAILY:-7}"
  printf 'keep_weekly=%s\n' "${BACKUP_KEEP_WEEKLY:-4}"
  printf 'keep_monthly=%s\n' "${BACKUP_KEEP_MONTHLY:-6}"
  printf 'archives=fgc-full-*,fgc-daily-*\n'
  printf 'prune=PASS\ncompact=PASS\n'
} > "$STATE_ROOT/last-retention.ok"
chmod 0600 "$STATE_ROOT/last-retention.ok"
rm -f "$STATE_ROOT/last-retention-skipped"
printf 'Borg retention completed: daily=%s weekly=%s monthly=%s (full + daily archives)\n' \
  "${BACKUP_KEEP_DAILY:-7}" "${BACKUP_KEEP_WEEKLY:-4}" "${BACKUP_KEEP_MONTHLY:-6}"
