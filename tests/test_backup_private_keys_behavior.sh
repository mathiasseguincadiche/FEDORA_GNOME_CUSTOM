#!/usr/bin/env bash
# Real helper execution: every Borg archive kind excludes SSH/GnuPG private
# material, whatever the caller passes (ADR 0021). tests/test_borg_roundtrip.sh
# proves the same with a real repository when borg is installed.
# shellcheck disable=SC2317,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export FAKE_ARGS="$tmp/borg-args"
cat > "$tmp/bin/borg" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == create ]]; then printf '%s\n' "$@" > "$FAKE_ARGS"; fi
exit 2
SH
chmod +x "$tmp/bin/borg"
export PATH="$tmp/bin:$PATH"
source "$ROOT/lib/backup_runtime.sh"

# The exclusion list itself covers both directories.
printf '%s\n' "${BACKUP_PRIVATE_KEY_EXCLUDES[@]}" | grep -Fxq '*/.ssh'
printf '%s\n' "${BACKUP_PRIVATE_KEY_EXCLUDES[@]}" | grep -Fxq '*/.gnupg'

for kind in preapply full daily; do
  rm -f "$FAKE_ARGS"
  backup_engine_create "$kind" -- "$HOME" >/dev/null 2>&1 || true
  [[ -s "$FAKE_ARGS" ]] || { echo "borg create not reached for $kind" >&2; exit 1; }
  for pattern in '*/.ssh' '*/.gnupg'; do
    grep -Fxq -- "$pattern" "$FAKE_ARGS" || { echo "$kind archive does not exclude $pattern" >&2; exit 1; }
  done
done

# A Borg exclusion cannot see into the pre-created /etc tarball. Exercise the
# actual GNU tar exclusions on a disposable fake system root, never on /etc.
system_fixture="$tmp/system-root"
mkdir -p "$system_fixture/etc/ssh" "$system_fixture/etc/NetworkManager/system-connections" \
  "$system_fixture/etc/ssl/private" "$system_fixture/etc/wireguard" \
  "$system_fixture/etc/libvirt" "$system_fixture/boot"
for safe in etc/hostname etc/ssh/sshd_config boot/vmlinuz-fixture; do
  printf 'safe fixture\n' > "$system_fixture/$safe"
done
for secret in etc/shadow etc/shadow- etc/gshadow etc/gshadow- \
  etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.old \
  etc/NetworkManager/system-connections/private.nmconnection \
  etc/ssl/private/server.key etc/wireguard/wg0.conf \
  etc/libvirt/private-domain.xml; do
  printf 'dummy secret fixture\n' > "$system_fixture/$secret"
done
tar -C "$system_fixture" "${BACKUP_SYSTEM_CONFIG_TAR_EXCLUDES[@]}" \
  -czf "$tmp/system-config.tar.gz" etc boot
tar -tzf "$tmp/system-config.tar.gz" > "$tmp/system-members"
for safe in etc/hostname etc/ssh/sshd_config boot/vmlinuz-fixture; do
  grep -Fxq "$safe" "$tmp/system-members" || {
    echo "Safe recovery fixture was excluded: $safe" >&2; exit 1;
  }
done
for secret in etc/shadow etc/shadow- etc/gshadow etc/gshadow- \
  etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.old \
  etc/NetworkManager/system-connections/private.nmconnection \
  etc/ssl/private/server.key etc/wireguard/wg0.conf \
  etc/libvirt/private-domain.xml; do
  if grep -Fxq "$secret" "$tmp/system-members"; then
    echo "Sensitive system fixture was archived: $secret" >&2; exit 1;
  fi
done

# Both production paths must use the SAME exclusions at tar creation time.
for script in "$ROOT/prepare-preapply-backup.sh" "$ROOT/scripts/backup/backup-now.sh"; do
  grep -Fq '"${BACKUP_SYSTEM_CONFIG_TAR_EXCLUDES[@]}"' "$script" || {
    echo "System-tar exclusions are not wired into $script" >&2; exit 1;
  }
done

# Sources no longer list the key directories by default.
if grep -Eq 'DAILY_BACKUP_EXTRA_PATHS=.*[.](ssh|gnupg)' "$ROOT/config/backup.conf"; then
  echo 'backup.conf still lists .ssh/.gnupg as daily sources' >&2; exit 1
fi
if grep -Eq 'for user_path in .*[.](ssh|gnupg)' "$ROOT/scripts/backup/backup-now.sh"; then
  echo 'full backup still lists .ssh/.gnupg as sources' >&2; exit 1
fi

echo 'backup private keys exclusion behavior: PASS'
