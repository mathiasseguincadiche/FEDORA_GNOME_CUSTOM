#!/usr/bin/env bash
# Nautilus integration run for real in a repository copy with fake dnf/rpm,
# gsettings, gio and systemctl: the module installs the Fedora-native stack,
# SMB/MTP only when enabled, removes the legacy terminal extension, applies the
# thumbnail policy and installs the Portal/GIO prewarm; the real doctor then
# refuses every missing piece. The IBus workaround stays opt-in and separate.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "nautilus integration behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME XDG_STATE_HOME
printf '#!/usr/bin/env bash\nprintf "doctor localsearch %%s\\n" "$*" >> "$T_LOG"\nexit "${T_LOCALSEARCH_RC:-0}"\n' > "$fixture/diagnostics/localsearch-doctor"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"'
fake dnf ':'
# rpm: every package installed except T_MISSING (gnome-terminal-nautilus and
# ibus-typing-booster only when listed in T_INSTALLED).
fake rpm 'case "$1" in
  -ql) [[ -n "${T_NO_EXTENSION:-}" ]] || echo /usr/lib64/nautilus/extensions-4/libnautilus-fileroller.so; exit 0 ;;
  -q) shift; [[ "$1" == --quiet ]] && shift
      for pkg; do
        case "$pkg" in gnome-terminal-nautilus|ibus-typing-booster) [[ " ${T_INSTALLED:-} " == *" $pkg "* ]] || exit 1 ;; esac
        for missing in ${T_MISSING:-}; do [[ "$pkg" != "$missing" ]] || exit 1; done
      done ;;
esac'
fake gsettings 'case "$1" in
  list-schemas) [[ -n "${T_NO_SCHEMA:-}" ]] || echo org.gnome.nautilus.preferences ;;
  get) cat "$T_TMP/thumbnails" 2>/dev/null || echo "'"'"'local-only'"'"'" ;;
  set) printf "%s\n" "$4" > "$T_TMP/thumbnails"; printf "gsettings set %s %s %s\n" "$2" "$3" "$4" >> "$T_LOG" ;;
esac'
fake gio '[[ "$1 $2" == "mount -l" ]] && exit "${T_GIO_RC:-0}"; exit 1'
fake systemctl '[[ "$1" == --user ]] || exit 99; shift
case "$1" in
  daemon-reload) printf "systemctl daemon-reload\n" >> "$T_LOG"; exit "${T_RELOAD_RC:-0}" ;;
  enable) printf "systemctl enable %s\n" "$2" >> "$T_LOG"; [[ -n "${T_ENABLE_RC:-}" ]] && exit "$T_ENABLE_RC"; echo "$2" >> "$T_TMP/enabled" ;;
  is-enabled) grep -Fxq "${@: -1}" "$T_TMP/enabled" 2>/dev/null ;;
  *) exit 99 ;;
esac'
fake xdg-user-dir 'echo "$HOME/Bureau"'
export PATH="$tmp/bin:$PATH"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
config_load
log_info() { :; }; log_error() { :; }
install_manifest_packages() { printf 'packages %s\n' "${2##*/}" >> "$T_LOG"; }
source "$fixture/modules/gnome/21_nautilus_integration.sh"
helper="$HOME/.local/libexec/fedora-gnome-nautilus-prewarm"
service="$HOME/.config/systemd/user/fedora-gnome-nautilus-prewarm.service"

# Precheck: dnf and a known thumbnail policy.
gnome_nautilus_precheck || fail 'Nautilus precheck refused the Golden configuration'
for policy in always local-only never; do NAUTILUS_PREVIEW_POLICY="$policy" gnome_nautilus_precheck || fail "policy $policy refused"; done
rc=0; NAUTILUS_PREVIEW_POLICY=remote-only gnome_nautilus_precheck || rc=$?
[[ "$rc" == "$EXIT_CONFIG_FAILED" ]] || fail "unknown thumbnail policy accepted (rc=$rc)"
rm "$tmp/bin/dnf"; rc=0; gnome_nautilus_precheck || rc=$?; fake dnf ':'
[[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "Nautilus precheck accepted a host without dnf (rc=$rc)"

# Preflight installs nothing in HOME and touches no user service.
DRY_RUN=true gnome_nautilus_apply || fail 'preflight Nautilus apply failed'
[[ "$(paste -sd'|' "$T_LOG")" == 'packages packages-nautilus.txt' && ! -e "$HOME/.local" && ! -e "$HOME/.config" ]] \
  || fail "preflight Nautilus apply changed the host: $(paste -sd'|' "$T_LOG")"

# Apply: Fedora stack, optional backends, legacy extension removed, policy, prewarm.
rm -f "$T_LOG"; T_INSTALLED=gnome-terminal-nautilus DRY_RUN=false gnome_nautilus_apply || fail 'Nautilus apply failed'
[[ "$(paste -sd'|' "$T_LOG")" == "packages packages-nautilus.txt|sudo dnf -y install gvfs-smb|sudo dnf -y install gvfs-mtp\
|sudo dnf -y remove gnome-terminal-nautilus|gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'local-only'\
|systemctl daemon-reload|systemctl enable fedora-gnome-nautilus-prewarm.service" ]] || fail "unexpected Nautilus apply: $(paste -sd'|' "$T_LOG")"
cmp "$helper" scripts/gnome/nautilus-prewarm.sh && [[ "$(stat -c %a "$helper")" == 755 ]] || fail 'prewarm helper not installed executable'
cmp "$service" systemd/user/fedora-gnome-nautilus-prewarm.service && [[ "$(stat -c %a "$service")" == 644 ]] || fail 'prewarm service not installed'
grep -Fq "ExecStart=%h/.local/libexec/fedora-gnome-nautilus-prewarm" "$service" || fail 'prewarm service does not run the installed helper'
grep -Eq '^[^#]*nautilus( |$)' scripts/gnome/nautilus-prewarm.sh && fail 'prewarm starts Nautilus itself'
# Options: no SMB/MTP when disabled, nothing removed when absent, previews off means never.
rm -f "$T_LOG"; NAUTILUS_ENABLE_SMB=false NAUTILUS_ENABLE_MTP=false NAUTILUS_ENABLE_PREVIEWS=false DRY_RUN=false gnome_nautilus_apply
[[ "$(paste -sd'|' "$T_LOG")" == "packages packages-nautilus.txt|gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'never'\
|systemctl daemon-reload|systemctl enable fedora-gnome-nautilus-prewarm.service" ]] || fail "unexpected optional Nautilus apply: $(paste -sd'|' "$T_LOG")"
rm -f "$T_LOG"; T_NO_SCHEMA=1 NAUTILUS_PREVIEW_POLICY=always DRY_RUN=false gnome_nautilus_apply
grep -q 'gsettings set' "$T_LOG" && fail 'thumbnail policy written without the Nautilus schema'
# Every failing step stops APPLY.
for override in T_RELOAD_RC=1 T_ENABLE_RC=1; do
  rc=0; (export "${override?}"; DRY_RUN=false gnome_nautilus_apply) || rc=$?
  [[ "$rc" == "$EXIT_APPLY_FAILED" ]] || fail "Nautilus apply ignored $override (rc=$rc)"
done
# A user unit directory that cannot be created (a file is in the way) stops APPLY.
mv "$HOME/.config/systemd/user" "$tmp/user-units"; touch "$HOME/.config/systemd/user"
rc=0; DRY_RUN=false gnome_nautilus_apply 2>/dev/null || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" ]] || fail "Nautilus apply ignored an install failure (rc=$rc)"
rm "$HOME/.config/systemd/user"; mv "$tmp/user-units" "$HOME/.config/systemd/user"
DRY_RUN=false gnome_nautilus_apply || fail 'Nautilus re-apply failed'

# Postcheck runs both doctors on APPLY only.
rm -f "$T_LOG"; DRY_RUN=true gnome_nautilus_postcheck && [[ ! -e "$T_LOG" ]] || fail 'preflight postcheck ran the doctors'
DRY_RUN=false gnome_nautilus_postcheck || fail 'applied Nautilus stack failed the postcheck'
grep -Fxq 'doctor localsearch --quiet' "$T_LOG" || fail 'postcheck skipped the LocalSearch doctor'
for override in T_LOCALSEARCH_RC=1 T_GIO_RC=1; do
  rc=0; (export "${override?}"; DRY_RUN=false gnome_nautilus_postcheck) || rc=$?
  [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "postcheck accepted $override (rc=$rc)"
done

# The real doctor refuses every missing piece of the stack.
doctor() { env "$@" bash diagnostics/nautilus-integration-doctor > "$tmp/out" 2>&1; }
doctor || { cat "$tmp/out" >&2; fail 'Nautilus doctor refused the applied stack'; }
refused() { # refused PATTERN WHY VAR=VALUE... : the doctor fails reporting PATTERN as KO
  local pattern="$1" why="$2" rc=0; shift 2
  doctor "$@" || rc=$?
  [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] && grep -Eq "^\[KO  \] .*$pattern" "$tmp/out" || { cat "$tmp/out" >&2; fail "Nautilus doctor accepted $why (rc=$rc)"; }
}
for pkg in nautilus gvfs gvfs-gphoto2 gvfs-fuse gvfs-afc gvfs-goa gvfs-nfs sushi file-roller-nautilus gvfs-smb gvfs-mtp; do
  refused "$pkg missing" "a missing $pkg" T_MISSING="$pkg"
done
doctor T_MISSING=gvfs-archive || fail 'Fedora 45 doctor required the removed gvfs-archive'
printf 'NAUTILUS_ENABLE_SMB="false"\nNAUTILUS_ENABLE_MTP="false"\n' > config/local.conf
doctor 'T_MISSING=gvfs-smb gvfs-mtp' || fail 'disabled SMB/MTP backends still required'
rm config/local.conf
refused 'Nautilus extension payload missing' 'File Roller without its Nautilus extension' T_NO_EXTENSION=1
refused 'gio mount enumeration failed' 'a broken GIO backend' T_GIO_RC=1
refused 'GSettings schema unavailable' 'a missing Nautilus schema' T_NO_SCHEMA=1
printf "'always'\n" > "$tmp/thumbnails"; refused "expected 'local-only', got 'always'" 'a drifted thumbnail policy'
printf "'local-only'\n" > "$tmp/thumbnails"
# Previews disabled: the doctor expects 'never' whatever the policy says.
printf 'NAUTILUS_ENABLE_PREVIEWS="false"\n' > config/local.conf
refused "expected 'never', got 'local-only'" 'thumbnails while previews are disabled'
printf "'never'\n" > "$tmp/thumbnails"; doctor || fail 'disabled previews with the never policy refused'
rm config/local.conf; printf "'local-only'\n" > "$tmp/thumbnails"
mv "$helper" "$tmp/helper"; refused 'helper missing' 'a missing prewarm helper'; mv "$tmp/helper" "$helper"
mv "$tmp/enabled" "$tmp/enabled.ok"; refused 'user service disabled' 'a disabled prewarm service'; mv "$tmp/enabled.ok" "$tmp/enabled"
fake xdg-user-dir 'echo "$HOME/Absent"'
doctor && grep -Fq 'WARN' "$tmp/out" || fail 'a missing XDG Desktop before DING convergence must only warn'
doctor || fail 'restored Nautilus stack refused'

# The IBus workaround is opt-in, separate from Nautilus, and only removes an installed package.
source "$fixture/modules/desktop/26_desktop_integration.sh"
[[ "$REMOVE_IBUS_TYPING_BOOSTER" == false ]] || fail 'IBus workaround enabled by default'
ibus() { rm -f "$T_LOG"; env "$@" bash -c "$(declare -f); DRY_RUN=false desktop_integration_apply"; grep -c 'remove ibus-typing-booster' "$T_LOG" || true; }
[[ "$(ibus T_INSTALLED=ibus-typing-booster)" == 0 ]] || fail 'IBus removed without the opt-in'
[[ "$(ibus REMOVE_IBUS_TYPING_BOOSTER=true)" == 0 ]] || fail 'IBus removal attempted while not installed'
[[ "$(ibus REMOVE_IBUS_TYPING_BOOSTER=true T_INSTALLED=ibus-typing-booster)" == 1 ]] || fail 'opt-in IBus removal not applied'
rm -f "$T_LOG"; T_INSTALLED='gnome-terminal-nautilus ibus-typing-booster' REMOVE_IBUS_TYPING_BOOSTER=true DRY_RUN=false gnome_nautilus_apply
grep -q ibus "$T_LOG" && fail 'Nautilus apply touched the IBus workaround'

echo 'nautilus integration behavior: PASS'
