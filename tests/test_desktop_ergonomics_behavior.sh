#!/usr/bin/env bash
# Desktop ergonomics run for real in a repository copy: the GNOME extension
# module installs DING and Show Desktop Button from the reviewed lock, sets
# ~/Bureau and their settings through fake gsettings/xdg-user-dirs stores,
# enables them once visible, and the postcheck and gnome-doctor refuse every
# drift from the Golden desktop.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015,SC2163
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "desktop ergonomics behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/gsettings"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

# The reviewed-artifact installer is exercised elsewhere; here it lays down
# what it would install and records the lock values it was given.
cat > "$fixture/scripts/gnome/install-pinned-extension.sh" <<'SH'
#!/usr/bin/env bash
printf 'install %s\n' "$*" >> "$T_LOG"
dir="$XDG_DATA_HOME/gnome-shell/extensions/$3"
mkdir -p "$dir/schemas"
echo '{}' > "$dir/metadata.json"
printf 'source_url=%s\n' "$2" > "$dir/.fedora-gnome-custom-source"
SH
printf '#!/usr/bin/env bash\nexit "${T_VITALS_RC:-0}"\n' > "$fixture/diagnostics/resource-monitor-doctor"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake gsettings '[[ "$1" == --schemadir ]] && shift 2
file="$T_TMP/gsettings/$2.$3"
case "$1" in
  get) [[ -r "$file" ]] && cat "$file" || echo unset ;;
  set) printf "%s\n" "$4" > "$file"; printf "gsettings %s %s\n" "$3" "$4" >> "$T_LOG" ;;
  *) exit 1 ;;
esac'
fake xdg-user-dirs-update '[[ "$1 $2" == "--set DESKTOP" ]] || exit 1; printf "%s\n" "$3" > "$T_TMP/xdg-desktop"'
fake xdg-user-dir '[[ "$1" == DESKTOP ]] || exit 1; cat "$T_TMP/xdg-desktop" 2>/dev/null || echo "$HOME/Desktop"'
fake gnome-extensions 'case "$1" in
  list) cat "$T_TMP/ext-visible" 2>/dev/null ;;
  info) grep -Fxq "$2" "$T_TMP/ext-active" 2>/dev/null && echo "  State: ACTIVE" || echo "  State: INACTIVE" ;;
  enable) printf "gnome-extensions enable %s\n" "$2" >> "$T_LOG"; printf "%s\n" "$2" >> "$T_TMP/ext-active" ;;
esac'
fake sudo 'printf "sudo %s\n" "${*##*/}" >> "$T_LOG"'
fake rpm 'for missing in ${T_MISSING:-}; do [[ "$2" != "$missing" ]] || exit 1; done'
fake flatpak 'printf "flatpak %s\n" "$*" >> "$T_LOG"'
fake systemctl 'exit 0'
fake dnf ':'
export PATH="$tmp/bin:$PATH"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
config_load
log_info() { :; }; log_error() { :; }
install_manifest_packages() { printf 'packages %s\n' "${2##*/}" >> "$T_LOG"; }
source "$fixture/modules/gnome/24_gnome_extensions.sh"
[[ "$HOST_RELEASE" == 45 ]] || fail "Golden profile is not Fedora 45 ($HOST_RELEASE)"
ding="$DING_UUID" button="$SHOW_DESKTOP_PLUS_UUID"
ding_store="$tmp/gsettings/$DING_SCHEMA" button_store="$tmp/gsettings/$SHOW_DESKTOP_PLUS_SCHEMA"
gnome_show_desktop_is_button || fail 'Fedora 45 lock does not select Show Desktop Button'

# Precheck: the Golden desktop passes, every other DING or Show Desktop choice is refused.
gnome_extensions_precheck || fail 'extension precheck refused the Golden desktop'
for override in DING_DESKTOP_DIR_NAME=Desktop DING_SHOW_TRASH=false DING_SHOW_HOME=true DING_SHOW_VOLUMES=true \
  DING_SHOW_NETWORK_VOLUMES=true SHOW_DESKTOP_PLUS_BUTTON_POSITION=right SHOW_DESKTOP_PLUS_LEFT_CLICK_ACTION=minimize \
  SHOW_DESKTOP_PLUS_ENABLE_HOTKEY=false 'SHOW_DESKTOP_PLUS_HOTKEY=<Super>h' ENABLE_JUST_PERFECTION=true; do
  rc=0; (export "$override"; gnome_extensions_precheck) || rc=$?
  [[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "extension precheck accepted $override (rc=$rc)"
done
(ENABLE_DESKTOP_ICONS_NG=false DING_SHOW_HOME=true ENABLE_SHOW_DESKTOP_PLUS=false SHOW_DESKTOP_PLUS_HOTKEY=x; gnome_extensions_precheck) \
  || fail 'disabled DING/Show Desktop values still checked'

# Preflight changes nothing.
DRY_RUN=true gnome_extensions_apply || fail 'preflight extension apply failed'
[[ "$(paste -sd'|' "$T_LOG")" == 'packages packages-gnome-extensions.txt' ]] || fail "preflight extension apply ran: $(paste -sd'|' "$T_LOG")"
[[ ! -e "$tmp/xdg-desktop" && -z "$(ls "$tmp/gsettings")" ]] || fail 'preflight wrote desktop settings'
DRY_RUN=true gnome_extensions_postcheck || fail 'preflight postcheck audited a desktop not applied yet'

# Apply: reviewed lock artifacts, ~/Bureau, DING and Show Desktop settings, enable once visible.
rm -f "$T_LOG"; rc=0; DRY_RUN=false gnome_extensions_apply || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" ]] || fail "extensions enabled while the session cannot see them (rc=$rc)"
grep -q 'gnome-extensions enable' "$T_LOG" && fail 'invisible extension enabled'
printf '%s\n' "$DASH_TO_DOCK_UUID" "$APPINDICATOR_UUID" "$ding" "$button" > "$tmp/ext-visible"
rm -f "$T_LOG"; DRY_RUN=false gnome_extensions_apply || fail 'extension apply failed'
expected="packages packages-gnome-extensions.txt|sudo bash install-fedora45-rpm-extensions.sh\
|install DING $DING_SOURCE_URL $ding 51|install SHOW_DESKTOP_PLUS $SHOW_DESKTOP_PLUS_SOURCE_URL $button 51\
|gsettings show-trash true|gsettings show-home false|gsettings show-volumes false|gsettings show-network-volumes false\
|gsettings indicator-position 'LEFT_END'|gsettings show-icon true|gsettings show-desktop-shortcut ['<Super>d']\
|gnome-extensions enable $DASH_TO_DOCK_UUID|gnome-extensions enable $APPINDICATOR_UUID|gnome-extensions enable $ding|gnome-extensions enable $button\
|flatpak install -y flathub $EXTENSION_MANAGER_FLATPAK_ID"
[[ "$(paste -sd'|' "$T_LOG")" == "$expected" ]] || fail "unexpected extension apply: $(paste -sd'|' "$T_LOG")"
[[ -d "$HOME/Bureau" && "$(xdg-user-dir DESKTOP)" == "$HOME/Bureau" ]] || fail 'XDG Desktop is not ~/Bureau'
[[ "$DING_SOURCE_URL" == https://extensions.gnome.org/review/download/* && "$SHOW_DESKTOP_PLUS_SOURCE_URL" == https://extensions.gnome.org/review/download/* ]] \
  || fail 'DING or Show Desktop not pinned to a GNOME review artifact'
rm -f "$T_LOG"; DRY_RUN=false gnome_extensions_apply || fail 'extension re-apply failed'
grep -q 'gnome-extensions enable' "$T_LOG" && fail 'active extension enabled again'

# Postcheck: the applied desktop passes, every drift is refused.
DRY_RUN=false gnome_extensions_postcheck || fail 'applied desktop failed the postcheck'
post_refused() { # post_refused WHY : the postcheck must fail on the current state
  local rc=0; DRY_RUN=false gnome_extensions_postcheck || rc=$?
  [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "extension postcheck accepted $1 (rc=$rc)"
}
drift() { # drift FILE VALUE WHY : one setting changed, refused, then restored
  cp "$1" "$tmp/saved"; printf '%s\n' "$2" > "$1"; post_refused "$3"; cp "$tmp/saved" "$1"
}
drift "$ding_store.show-trash" false 'a hidden Trash'
drift "$ding_store.show-home" true 'a Home icon'
drift "$ding_store.show-volumes" true 'external volume icons'
drift "$ding_store.show-network-volumes" true 'network volume icons'
drift "$tmp/xdg-desktop" "$HOME/Desktop" 'an XDG Desktop outside ~/Bureau'
drift "$button_store.indicator-position" "'RIGHT'" 'a moved Show Desktop button'
drift "$button_store.show-desktop-shortcut" "['']" 'no Super+D shortcut'
marker="$XDG_DATA_HOME/gnome-shell/extensions/$ding/.fedora-gnome-custom-source"
drift "$marker" 'source_url=https://example.invalid/ding.zip' 'DING from another source'
for uuid in "$ding" "$button"; do
  meta="$XDG_DATA_HOME/gnome-shell/extensions/$uuid/metadata.json"
  mv "$meta" "$tmp/meta"; post_refused "a missing $uuid payload"; mv "$tmp/meta" "$meta"
  cp "$tmp/ext-active" "$tmp/active"; grep -Fxv "$uuid" "$tmp/active" > "$tmp/ext-active"
  post_refused "an inactive $uuid"; cp "$tmp/active" "$tmp/ext-active"
done
DRY_RUN=false gnome_extensions_postcheck || fail 'restored desktop failed the postcheck'
(ENABLE_DESKTOP_ICONS_NG=false ENABLE_SHOW_DESKTOP_PLUS=false; printf 'true\n' > "$ding_store.show-home"
  DRY_RUN=false gnome_extensions_postcheck) || fail 'disabled DING/Show Desktop still audited'
printf 'false\n' > "$ding_store.show-home"

# gnome-doctor audits the same desktop inside a GNOME Wayland session (Vitals is
# installed by its own module, laid down here).
bash scripts/gnome/install-pinned-extension.sh RESOURCE_MONITOR "$RESOURCE_MONITOR_SOURCE_URL" "$RESOURCE_MONITOR_UUID"
echo "$RESOURCE_MONITOR_UUID" | tee -a "$tmp/ext-visible" >> "$tmp/ext-active"
doctor() { env XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=wayland bash diagnostics/gnome-doctor > "$tmp/out" 2>&1; }
doctor || { cat "$tmp/out" >&2; fail 'gnome-doctor refused the applied desktop'; }
doctor_refuses() { # doctor_refuses LABEL WHY : the doctor must fail and report LABEL as KO
  local rc=0; doctor || rc=$?
  [[ "$rc" != 0 ]] && grep -Eq "^\[KO  \] $1" "$tmp/out" || fail "gnome-doctor accepted $2"
}
doctor_drift() { # doctor_drift FILE VALUE LABEL WHY
  cp "$1" "$tmp/saved"; printf '%s\n' "$2" > "$1"; doctor_refuses "$3" "$4"; cp "$tmp/saved" "$1"
}
doctor_drift "$ding_store.show-trash" false 'DING Trash' 'a hidden Trash'
doctor_drift "$ding_store.show-home" true 'DING Home' 'a Home icon'
doctor_drift "$ding_store.show-volumes" true 'DING external volumes' 'external volume icons'
doctor_drift "$ding_store.show-network-volumes" true 'DING network volumes' 'network volume icons'
doctor_drift "$tmp/xdg-desktop" "$HOME/Desktop" 'Desktop directory' 'an XDG Desktop outside ~/Bureau'
doctor_drift "$button_store.indicator-position" "'RIGHT'" 'Show Desktop position' 'a moved Show Desktop button'
doctor_drift "$button_store.show-desktop-shortcut" "['']" 'Show Desktop Super\+D' 'no Super+D shortcut'
doctor_drift "$marker" 'source_url=https://example.invalid/ding.zip' 'Desktop Icons NG provenance' 'DING from another source'
mv "$HOME/Bureau" "$tmp/Bureau"; doctor_refuses 'Desktop directory' 'a missing ~/Bureau'; mv "$tmp/Bureau" "$HOME/Bureau"
cp "$tmp/ext-active" "$tmp/active"; grep -Fxv "$button" "$tmp/active" > "$tmp/ext-active"
doctor_refuses 'Show Desktop Plus / Button state' 'an inactive Show Desktop Button'; cp "$tmp/active" "$tmp/ext-active"
printf 'ENABLE_JUST_PERFECTION="true"\n' > config/local.conf
doctor_refuses 'Just Perfection' 'Just Perfection enabled'
rm config/local.conf
# Outside a GNOME session the per-user settings are not audited.
printf 'true\n' > "$ding_store.show-home"
bash diagnostics/gnome-doctor > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'gnome-doctor audited settings outside a GNOME session'; }
doctor_refuses 'DING Home' 'a Home icon in the session'

echo 'desktop ergonomics behavior: PASS'
