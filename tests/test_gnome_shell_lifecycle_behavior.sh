#!/usr/bin/env bash
# Test the real module and writer inside an isolated home; no desktop is stopped.
# shellcheck disable=SC2034,SC2317,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail(){ echo "GNOME Shell lifecycle behavior: $*" >&2; exit 1; }
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" REPO_ROOT="$tmp/repo" HOST_RELEASE=45
mkdir -p "$HOME" "$tmp/bin" "$REPO_ROOT/scripts/gnome" "$REPO_ROOT/systemd/user/org.gnome.Shell@user.service.d"
cp "$ROOT/scripts/gnome/configure-shell-lifecycle.sh" "$REPO_ROOT/scripts/gnome/"
relative=systemd/user/org.gnome.Shell@user.service.d/50-fgc-child-lifecycle.conf
cp "$ROOT/$relative" "$REPO_ROOT/$relative"
target="$XDG_CONFIG_HOME/$relative"
export FGC_FIXTURE_TARGET="$target" FGC_FIXTURE_RELOADS="$tmp/reloads"
cat > "$tmp/bin/systemctl" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$*" in
  '--user daemon-reload')
    [[ "${FGC_FIXTURE_RELOAD_FAILURE:-false}" != true ]] || exit 1
    echo reload >> "$FGC_FIXTURE_RELOADS"
    ;;
  '--user show org.gnome.Shell@user.service --property=KillMode --value')
    if [[ -n "${FGC_FIXTURE_OVERRIDE:-}" ]]; then echo "$FGC_FIXTURE_OVERRIDE"
    else sed -n 's/^KillMode=//p' "$FGC_FIXTURE_TARGET"; fi
    ;;
  *) exit 3 ;;
esac
SH
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/rpm"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/mutations.sh"
source "$ROOT/modules/gnome/20_gnome_core.sh"
log_info(){ :; }
is_true(){ [[ "$1" == true ]]; }
install_manifest_packages(){ [[ "${FGC_FIXTURE_PACKAGE_FAILURE:-false}" != true ]]; }

DRY_RUN=true
gnome_core_apply
[[ ! -e "$target" && ! -e "$tmp/reloads" ]] || fail 'dry-run mutated user services'
gnome_core_postcheck

DRY_RUN=false
HOST_RELEASE=44
gnome_core_apply
[[ ! -e "$target" ]] || fail 'historical release was changed'
HOST_RELEASE=45

FGC_FIXTURE_PACKAGE_FAILURE=true
rc=0; gnome_core_apply || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" && ! -e "$target" ]] || fail 'package failure did not stop the writer'
FGC_FIXTURE_PACKAGE_FAILURE=false

gnome_core_apply
cmp -s "$ROOT/$relative" "$target" || fail 'wrong user-service path or content'
[[ -s "$tmp/reloads" ]] || fail 'user service manager was not reloaded'
gnome_core_postcheck
gnome_core_apply
cmp -s "$ROOT/$relative" "$target" || fail 'repeated apply changed the policy'

export FGC_FIXTURE_OVERRIDE=control-group
rc=0; gnome_core_postcheck > "$tmp/override.log" 2>&1 || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'effective override was accepted'
unset FGC_FIXTURE_OVERRIDE

printf '\nKillMode=process\n' >> "$target"
rc=0; gnome_core_postcheck > "$tmp/drift.log" 2>&1 || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'changed drop-in was accepted'
rm "$target"
rc=0; gnome_core_postcheck > "$tmp/missing.log" 2>&1 || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail 'missing drop-in was accepted'

export FGC_FIXTURE_RELOAD_FAILURE=true
rc=0; gnome_core_apply || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" ]] || fail 'daemon-reload failure was accepted'
unset FGC_FIXTURE_RELOAD_FAILURE
echo 'GNOME Shell lifecycle behavior: PASS'
