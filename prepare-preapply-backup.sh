#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=lib/backup_runtime.sh
source "$REPO_ROOT/lib/backup_runtime.sh"

fail() { printf 'BACKUP BLOCKED: %s\n' "$*" >&2; exit 20; }
apply_gate_require_clean_git || fail 'tracked Git worktree must be clean'
apply_gate_require_dryrun || fail 'same-commit FULL DRY-RUN PASS proof is required'

for cmd in restic jq findmnt lsblk python3 git rpm tar df stat; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Installing protected backup prerequisites...\n'
    sudo dnf -y install restic jq acl tar gzip findutils pciutils iproute
    break
  fi
done

repo="$(backup_runtime_resolve_repository)" || fail 'cannot resolve exactly one proven external/off-machine Restic repository'
password_file="$(backup_runtime_prepare_password)" || fail 'Restic password file is missing, insecure or passphrase creation failed'
backup_runtime_require_free_space "$repo" || fail 'backup target does not satisfy minimum free-space policy'

if ! backup_runtime_is_remote_repository "$repo"; then
  mkdir -p "$repo" 2>/dev/null || {
    sudo install -d -m 0700 -o "$(id -u)" -g "$(id -g)" "$repo"
  }
  backup_runtime_validate_local_target "$repo" || fail 'local Restic repository is not proven external/read-write'
fi
backup_runtime_export_env "$repo" "$password_file"

if ! restic cat config >/dev/null 2>&1; then
  [[ -t 0 ]] || fail 'interactive TTY required to initialize Restic repository'
  phrase="${BACKUP_PREAPPLY_CONFIRMATION_PHRASE:-JE_CONFIRME_LA_CREATION_DU_BACKUP_PRE_APPLY}"
  printf 'Repository not initialized: %s\nType exactly "%s": ' "$repo" "$phrase"
  read -r answer
  [[ "$answer" == "$phrase" ]] || fail 'repository initialization confirmation refused'
  restic init
fi

staging="$STATE_ROOT/preapply-staging/$RUN_ID"
rm -rf "$staging"
mkdir -p "$staging/inventory" "$staging/libvirt"
backup_runtime_capture_inventory "$staging/inventory"
printf 'fedora-gnome-custom restore canary\ncommit=%s\n' "$(repo_commit)" > "$staging/restore-canary.txt"
backup_runtime_export_libvirt "$staging/libvirt"

printf 'Capturing privileged Fedora configuration metadata...\n'
sudo tar -C / --xattrs --acls --selinux --numeric-owner -czf "$staging/fedora-system-config.tar.gz" etc boot
sudo chown "$(id -u):$(id -g)" "$staging/fedora-system-config.tar.gz"

sources=("$staging")
[[ -d "$HOME/.config" ]] && sources+=("$HOME/.config")
[[ -d "$HOME/.local/share/gnome-shell" ]] && sources+=("$HOME/.local/share/gnome-shell")
while IFS= read -r -d '' tracked; do sources+=("$REPO_ROOT/$tracked"); done < <(git -C "$REPO_ROOT" ls-files -z)

printf 'Creating encrypted pre-APPLY snapshot...\n'
restic backup --tag fedora-gnome-custom-preapply "${sources[@]}"
snap="$(restic snapshots --tag fedora-gnome-custom-preapply --latest 1 --json | jq -r '.[0].id // empty')"
[[ "$snap" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'Restic did not return one valid snapshot id'

printf 'Running Restic repository integrity check...\n'
restic check --read-data-subset=1/20

printf 'Running restore-canary proof...\n'
restore_test="$(mktemp -d)"
trap 'rm -rf "$restore_test" "$staging"' EXIT
restic restore "$snap" --target "$restore_test" --include '*/restore-canary.txt' >/dev/null
restored_canary="$(find "$restore_test" -type f -name restore-canary.txt -print -quit)"
[[ -n "$restored_canary" ]] || fail 'restore canary was not recovered'
cmp -s "$staging/restore-canary.txt" "$restored_canary" || fail 'restore canary content mismatch'

printf 'snapshot=%s\ncommit=%s\nutc=%s\nrepository=%s\npassword_file=%s\nrestore_test=PASS\nintegrity_check=PASS\n' \
  "$snap" "$(repo_commit)" "$(date -u +%FT%TZ)" "$repo" "$password_file" > "$STATE_ROOT/preapply-backup.ok"
chmod 0600 "$STATE_ROOT/preapply-backup.ok"
printf 'Verified same-commit pre-APPLY backup: %s\n' "$snap"
