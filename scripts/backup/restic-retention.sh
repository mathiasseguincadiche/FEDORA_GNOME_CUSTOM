#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

strict=false
[[ "${1:-}" == --strict ]] && strict=true
[[ $# -le 1 ]] || { echo 'Usage: restic-retention.sh [--strict]' >&2; exit 2; }

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
    echo "Restic retention failed: $reason" >&2
    exit 20
  fi
  exit 0
}

repo="$(backup_runtime_resolve_repository 2>/dev/null || true)"
password_file="$(backup_runtime_require_password 2>/dev/null || true)"
[[ -n "$repo" && -n "$password_file" ]] || skip_or_fail repository-or-password-unavailable
backup_runtime_export_env "$repo" "$password_file"
restic cat config >/dev/null 2>&1 || skip_or_fail repository-unreachable

# Restic defaults to grouping forget policies by host+paths. The full backup
# includes a timestamped staging path, so path grouping would fragment the
# retention set and could preserve far more snapshots than intended. Group by
# host+tags instead: one policy group per workstation and snapshot class.
for tag in fedora-gnome-custom-full fedora-gnome-custom-daily; do
  restic forget --tag "$tag" \
    --group-by host,tags \
    --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
    --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
    --keep-monthly "${RESTIC_KEEP_MONTHLY:-6}"
done
restic prune

{
  printf 'utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'runtime_sha=%s\n' "$FEDORA_GNOME_CUSTOM_RUNTIME_SHA"
  printf 'repository=%s\n' "$repo"
  printf 'group_by=host,tags\n'
  printf 'keep_daily=%s\n' "${RESTIC_KEEP_DAILY:-7}"
  printf 'keep_weekly=%s\n' "${RESTIC_KEEP_WEEKLY:-4}"
  printf 'keep_monthly=%s\n' "${RESTIC_KEEP_MONTHLY:-6}"
  printf 'tags=fedora-gnome-custom-full,fedora-gnome-custom-daily\n'
  printf 'prune=PASS\n'
} > "$STATE_ROOT/last-retention.ok"
chmod 0600 "$STATE_ROOT/last-retention.ok"
rm -f "$STATE_ROOT/last-retention-skipped"
printf 'Restic retention completed: group-by=host,tags daily=%s weekly=%s monthly=%s\n' \
  "${RESTIC_KEEP_DAILY:-7}" "${RESTIC_KEEP_WEEKLY:-4}" "${RESTIC_KEEP_MONTHLY:-6}"
