#!/usr/bin/env bash
# shellcheck disable=SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/common.sh"
journalctl() {
  case "$JOURNAL_CASE" in
    unreadable) return 1 ;;
    empty) return 0 ;;
    permission) printf -- '-- No entries --\n'; echo 'Not seeing other users journal due to insufficient permissions' >&2 ;;
    clean) printf 'boot complete\n' ;;
    fault) printf 'nvme controller reset\n' ;;
    large) printf 'nvme controller reset\n'; for ((i=0;i<20000;i++)); do printf 'ordinary event %s\n' "$i"; done ;;
  esac
}
for JOURNAL_CASE in unreadable empty permission fault large; do
  if kernel_journal_require_clean 'nvme.*reset'; then echo "False PASS: $JOURNAL_CASE" >&2; exit 1; fi
done
JOURNAL_CASE=clean
kernel_journal_require_clean 'nvme.*reset'
if kernel_journal_require_clean '['; then echo 'Invalid regex accepted' >&2; exit 1; fi
echo 'Kernel journal behavior: PASS'
