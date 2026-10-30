#!/usr/bin/env bash
# Daily backup runtime run for real in a repository copy with fake systemctl
# and Borg: APPLY installs an immutable, content-verified bundle named after the
# commit and configuration, binds the daily and retention user units to it
# (never to the checkout), refuses to overwrite a tampered bundle, and the
# installed bundle keeps working after the checkout is gone.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'chmod -R u+w "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
fail() { echo "backup daily runtime behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/home/.local/state" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME BORG_REPO
printf '#!/usr/bin/env bash\nprintf "doctor %%s\\n" "$*" >> "$T_LOG"\nexit "${T_DOCTOR_RC:-0}"\n' > "$fixture/diagnostics/daily-backup-doctor"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake systemctl '[[ "$1" == --user ]] || exit 99; shift
printf "systemctl %s\n" "$*" >> "$T_LOG"
case "$1" in
  daemon-reload) ;;
  enable) grep -Fxq "${@: -1}" "$T_TMP/enabled" 2>/dev/null || printf "%s\n" "${@: -1}" >> "$T_TMP/enabled" ;;
  disable) [[ ! -e "$T_TMP/enabled" ]] || { grep -Fxv "${@: -1}" "$T_TMP/enabled" > "$T_TMP/enabled.new" || true; mv "$T_TMP/enabled.new" "$T_TMP/enabled"; } ;;
  is-enabled) grep -Fxq "${@: -1}" "$T_TMP/enabled" 2>/dev/null ;;
  *) exit 99 ;;
esac'
export PATH="$tmp/bin:$PATH"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
source "$fixture/config/backup.conf"
BACKUP_REPOSITORY='ssh://backup@nas.example/./fgc'   # the owner's config/local.conf value
log_info() { :; }; log_error() { :; }
PERSISTENT_DATA_IDENTITY_FILE="$tmp/storage-identity.json"
printf '{"data": "approved"}\n' > "$PERSISTENT_DATA_IDENTITY_FILE"
sha=0123456789abcdef0123456789abcdef01234567
repo_commit() { echo "${T_SHA:-$sha}"; }
source "$fixture/modules/backup/60_daily_user_backup.sh"
units="$HOME/.config/systemd/user"
base="$HOME/.local/lib/fedora-gnome-custom/backup-runtime"

# Precheck: every bundled file present and a valid retention schedule.
backup_daily_precheck || fail 'daily backup precheck refused the Golden configuration'
(DAILY_BACKUP_ENABLED=false; mv lib/persistent_data_identity.py "$tmp/id.py"; backup_daily_precheck; rc=$?; mv "$tmp/id.py" lib/persistent_data_identity.py; exit "$rc") \
  || fail 'disabled daily backup still prechecked'
mv lib/backup_runtime_bundle.sh "$tmp/bundle.sh"; rc=0; backup_daily_precheck || rc=$?; mv "$tmp/bundle.sh" lib/backup_runtime_bundle.sh
[[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "daily backup precheck accepted a missing bundle library (rc=$rc)"
for override in BACKUP_RETENTION_RANDOMIZED_DELAY_SEC=30m BACKUP_RETENTION_ON_CALENDAR=; do
  rc=0; (export "${override?}"; backup_daily_precheck) || rc=$?
  [[ "$rc" == "$EXIT_CONFIG_FAILED" ]] || fail "daily backup precheck accepted $override (rc=$rc)"
done

# Apply refuses to pin a runtime without a real commit; preflight installs nothing.
rc=0; T_SHA=unknown DRY_RUN=false backup_daily_apply || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" && ! -e "$base" ]] || fail "runtime pinned without a Git commit (rc=$rc)"
DRY_RUN=true backup_daily_apply || fail 'preflight daily backup apply failed'
[[ ! -e "$base" && ! -e "$units" && ! -e "$T_LOG" ]] || fail 'preflight daily backup apply changed the host'

# Apply: an immutable bundle and units bound to it, never to the checkout.
mkdir -p "$units"; touch "$units/fedora-gnome-restic-retention.timer" "$units/fedora-gnome-restic-retention.service"
BORG_PASSPHRASE=ambient-secret BACKUP_INJECTED_BY_CALLER=leak DRY_RUN=false backup_daily_apply || fail 'daily backup apply failed'
runtime="$(backup_daily_runtime_dir "$sha")"
[[ "$runtime" == "$base/$sha-"* && -d "$runtime" ]] || fail "runtime not named after commit and configuration: $runtime"
(cd "$runtime" && sha256sum --check --status MANIFEST.sha256) || fail 'runtime manifest does not verify'
for file in bin/daily-user-backup bin/backup-retention lib/backup_runtime.sh lib/backup_runtime_bundle.sh lib/persistent_data.sh lib/persistent_data_identity.py; do
  grep -Fq " ./$file" "$runtime/MANIFEST.sha256" || grep -Fq "  $file" "$runtime/MANIFEST.sha256" || fail "runtime manifest lacks $file"
done
cmp "$runtime/bin/daily-user-backup" scripts/backup/daily-user-backup.sh && cmp "$runtime/bin/backup-retention" scripts/backup/backup-retention.sh \
  || fail 'runtime binaries differ from the repository'
cmp "$runtime/runtime/data-storage-identity.json" "$PERSISTENT_DATA_IDENTITY_FILE" || fail 'approved /data identity not embedded'
[[ "$(<"$runtime/runtime/APPLIED_SHA")" == "$sha" ]] || fail 'runtime APPLIED_SHA differs'
[[ "$(stat -c %a "$runtime/runtime/backup-runtime.conf")" == 600 && "$(stat -c %a "$runtime/runtime/data-storage-identity.json")" == 600 ]] \
  || fail 'runtime configuration or identity readable by others'
grep -Fq -e ambient-secret -e BACKUP_INJECTED_BY_CALLER "$runtime/runtime/backup-runtime.conf" && fail 'ambient variables serialized into the runtime'
grep -Fxq "BACKUP_REPOSITORY=$(printf '%q' "$BACKUP_REPOSITORY")" "$runtime/runtime/backup-runtime.conf" || fail 'runtime configuration lacks the repository'
for unit in fedora-gnome-daily-backup fedora-gnome-backup-retention; do
  grep -Fxq "Environment=\"FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=$runtime\"" "$units/$unit.service" || fail "$unit not bound to the runtime"
  grep -Fq "$fixture" "$units/$unit.service" && fail "$unit depends on the checkout"
done
grep -Fxq "ExecStart=$runtime/bin/daily-user-backup" "$units/fedora-gnome-daily-backup.service" \
  && grep -Fxq "ExecStart=$runtime/bin/backup-retention" "$units/fedora-gnome-backup-retention.service" || fail 'units do not run the bundled binaries'
cmp "$units/fedora-gnome-daily-backup.timer" systemd/user/fedora-gnome-daily-backup.timer || fail 'daily timer differs from the repository'
grep -Fxq "OnCalendar=$BACKUP_RETENTION_ON_CALENDAR" "$units/fedora-gnome-backup-retention.timer" \
  && grep -Fxq "RandomizedDelaySec=$BACKUP_RETENTION_RANDOMIZED_DELAY_SEC" "$units/fedora-gnome-backup-retention.timer" || fail 'retention timer ignores the configuration'
[[ ! -e "$units/fedora-gnome-restic-retention.timer" && ! -e "$units/fedora-gnome-restic-retention.service" ]] || fail 'former Restic units kept'
grep -Fxq 'systemctl disable --now fedora-gnome-restic-retention.timer' "$T_LOG" || fail 'former Restic timer not stopped'
[[ "$(paste -sd'|' "$tmp/enabled")" == 'fedora-gnome-daily-backup.timer|fedora-gnome-backup-retention.timer' ]] || fail "unexpected timers: $(paste -sd'|' "$tmp/enabled")"
[[ -z "$(find "$base" -maxdepth 1 -name '.*' ! -name . -print)" && -z "$(find "$units" -name '.fgc-unit.*' -print)" ]] || fail 'temporary files left behind'

# Re-APPLY of the same commit and configuration reuses the verified bundle.
DRY_RUN=false backup_daily_apply || fail 'daily backup re-apply failed'
[[ "$(find "$base" -mindepth 1 -maxdepth 1 | wc -l)" == 1 ]] || fail 'runtime duplicated on re-apply'

# Postcheck: the applied runtime passes, every drift is refused.
rm -f "$T_LOG"; DRY_RUN=false backup_daily_postcheck || fail 'applied runtime failed the postcheck'
grep -Fxq 'doctor --quiet' "$T_LOG" || fail 'postcheck skipped the daily backup doctor'
post_refused() { local rc=0; DRY_RUN=false backup_daily_postcheck || rc=$?; [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "postcheck accepted $1 (rc=$rc)"; }
T_DOCTOR_RC=1 post_refused 'a failing daily backup doctor'
cp "$tmp/enabled" "$tmp/enabled.ok"
grep -Fxv fedora-gnome-daily-backup.timer "$tmp/enabled.ok" > "$tmp/enabled"; post_refused 'a disabled daily timer'
grep -Fxv fedora-gnome-backup-retention.timer "$tmp/enabled.ok" > "$tmp/enabled"; post_refused 'a disabled retention timer'
cp "$tmp/enabled.ok" "$tmp/enabled"
cp "$units/fedora-gnome-daily-backup.service" "$tmp/service"
sed -i "s|$runtime|$fixture|" "$units/fedora-gnome-daily-backup.service"; post_refused 'a service bound to the checkout'
cp "$tmp/service" "$units/fedora-gnome-daily-backup.service"
T_SHA=fedcba9876543210fedcba9876543210fedcba98 post_refused 'a runtime of another commit'
BACKUP_KEEP_DAILY=99 post_refused 'a runtime of another configuration'
# A bundle edited and re-manifested in place still has to match its name.
reforge() { (cd "$runtime" && chmod -R u+w . && find bin lib runtime -type f -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256); }
cp -a "$runtime" "$tmp/runtime.ok"
printf 'fedcba9876543210fedcba9876543210fedcba98\n' > "$runtime/runtime/APPLIED_SHA"; reforge; post_refused 'a bundle relabelled with another commit'
rm -rf "$runtime"; cp -a "$tmp/runtime.ok" "$runtime"
printf 'BACKUP_KEEP_DAILY=99\n' >> "$runtime/runtime/backup-runtime.conf"; reforge; post_refused 'a bundle with an edited configuration'
rm -rf "$runtime"; cp -a "$tmp/runtime.ok" "$runtime"
DRY_RUN=false backup_daily_postcheck || fail 'restored runtime failed the postcheck'

# A tampered bundle is never replaced (evidence kept) and fails integrity at run time.
chmod u+w "$runtime/bin/backup-retention"; printf '# tamper\n' >> "$runtime/bin/backup-retention"
rc=0; DRY_RUN=false backup_daily_apply 2> "$tmp/err" || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" ]] && grep -Fq 'Refusing to replace invalid immutable backup runtime' "$tmp/err" || fail "tampered runtime replaced (rc=$rc)"
grep -Fxq '# tamper' "$runtime/bin/backup-retention" || fail 'tampered runtime evidence destroyed'
post_refused 'a tampered runtime'
rc=0; FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/backup-retention" > "$tmp/out" 2>&1 || rc=$?
[[ "$rc" == 20 ]] && grep -Fq 'integrity check failed' "$tmp/out" || fail "tampered runtime executed (rc=$rc)"
sed -i '$d' "$runtime/bin/backup-retention"

# Retention timer disabled by configuration: stopped, and not required.
BACKUP_PRUNE_AUTOMATICALLY=false
runtime2="$(backup_daily_runtime_dir "$sha")"
DRY_RUN=false backup_daily_apply || fail 'apply without automatic prune failed'
[[ "$runtime2" != "$runtime" && -d "$runtime2" ]] || fail 'configuration change did not create a new runtime'
[[ "$(paste -sd'|' "$tmp/enabled")" == fedora-gnome-daily-backup.timer ]] || fail "retention timer kept: $(paste -sd'|' "$tmp/enabled")"
DRY_RUN=false backup_daily_postcheck || fail 'postcheck required a disabled retention timer'
BACKUP_PRUNE_AUTOMATICALLY=true
DRY_RUN=false backup_daily_apply

# The installed runtime works without the checkout and uses only its snapshot.
fake borg 'printf "%s|repo=%s|passphrase=[%s]\n" "$*" "${BORG_REPO:-}" "${BORG_PASSPHRASE-unset}" >> "$T_TMP/borg.log"
case "$1" in
  --version) echo "borg 1.4.5" ;;
  info) echo "{\"encryption\": {\"mode\": \"none\"}}" ;;
  prune|compact|delete) ;;
  list) ;;
  *) exit 2 ;;
esac'
mv "$fixture" "$tmp/checkout-gone"
cd "$tmp"
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" BORG_PASSPHRASE=ambient-secret BACKUP_REPOSITORY=/ambient/repo \
  bash "$runtime/bin/backup-retention" > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'installed runtime failed without the checkout'; }
grep -Fq "prune --glob-archives fgc-daily-* --keep-daily $BACKUP_KEEP_DAILY --keep-weekly $BACKUP_KEEP_WEEKLY --keep-monthly $BACKUP_KEEP_MONTHLY|repo=$BACKUP_REPOSITORY|" "$tmp/borg.log" \
  || fail "installed runtime ignored its configuration snapshot: $(head -n3 "$tmp/borg.log")"
grep -Fq -e ambient-secret -e /ambient/repo "$tmp/borg.log" && fail 'ambient Borg settings reached the installed runtime'
grep -Fxq "engine=borg" "$XDG_STATE_HOME/fedora-gnome-custom/last-retention.ok" || fail 'retention marker not written'
grep -Fq fgc-preapply "$tmp/borg.log" && fail 'retention touched pre-APPLY archives'

echo 'backup daily runtime behavior: PASS'
