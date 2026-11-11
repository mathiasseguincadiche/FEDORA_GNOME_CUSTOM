#!/usr/bin/env bash
# Explicit, per-user installation of the optional retention timer. Never enables it silently.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if (( EUID == 0 )); then
  echo 'Run as the GNOME desktop user, not root.' >&2
  exit 1
fi
if [[ $# -ne 0 ]]; then
  echo 'Usage: scripts/maintenance/install-weekly-log-cleanup.sh' >&2
  exit 2
fi
if ! command -v systemctl >/dev/null 2>&1; then
  echo 'systemctl missing; cannot configure the user timer.' >&2
  exit 1
fi
if [[ -L "$REPO_ROOT/config/operator-retention.policy" || ! -f "$REPO_ROOT/config/operator-retention.policy" ]]; then
  echo 'Retention policy missing or unsafe.' >&2
  exit 1
fi

helper_dir="$HOME/.local/libexec"
unit_dir="$HOME/.config/systemd/user"
helper="$helper_dir/fgc-weekly-log-cleanup"
umask 077
mkdir -p -- "$helper_dir" "$unit_dir"
temp_helper="$(mktemp "$helper_dir/.fgc-weekly-log-cleanup.XXXXXXXX")"
trap 'rm -f -- "$temp_helper"' EXIT
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  printf 'exec /usr/bin/python3 %q --root %q --apply\n' \
    "$REPO_ROOT/scripts/maintenance/weekly-log-cleanup.py" "$REPO_ROOT"
} > "$temp_helper"
chmod 0700 "$temp_helper"
mv -f -- "$temp_helper" "$helper"
install -m 0644 "$REPO_ROOT/systemd/user/fgc-weekly-log-cleanup.service" "$unit_dir/fgc-weekly-log-cleanup.service"
install -m 0644 "$REPO_ROOT/systemd/user/fgc-weekly-log-cleanup.timer" "$unit_dir/fgc-weekly-log-cleanup.timer"
systemctl --user daemon-reload
printf 'Optional user timer installed for repository: %s\n' "$REPO_ROOT"
printf '%s\n' 'Review the dry run first:'
printf '  python3 %q --root %q\n' "$REPO_ROOT/scripts/maintenance/weekly-log-cleanup.py" "$REPO_ROOT"
printf '%s\n' 'Enable only if desired: systemctl --user enable --now fgc-weekly-log-cleanup.timer'
