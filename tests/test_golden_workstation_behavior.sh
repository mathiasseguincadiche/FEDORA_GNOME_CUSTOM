#!/usr/bin/env bash
# Golden workstation surfaces run for real in a repository copy with fake
# desktop and hardware commands: GNOME window controls, the display watcher,
# the /data layout, the Kickstart generator, the display doctor and the
# Nautilus cold-start doctor. Nothing touches the host session or disks.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "golden workstation behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/home/.local/state" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME XDG_CURRENT_DESKTOP

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake gsettings 'printf "gsettings %s\n" "$*" >> "$T_LOG"
case "$1 $3" in
  "list-keys ") printf "%s\n" theme ${T_KEYS-button-layout} ;;
  "get button-layout") printf "%s\n" "'\''$(cat "$T_TMP/layout")'\''" ;;
  "set button-layout") printf "%s" "$4" > "$T_TMP/layout" ;;
  "get "*) echo fixture ;;
esac'
fake gdbus 'printf "gdbus %s\n" "$*" >> "$T_LOG"
case "$*" in
  *login1*) printf "%s\n" "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)" \
    "/org/freedesktop/login1: org.freedesktop.login1.Manager.SessionNew (\"3\",)" \
    "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)" ;;
  *Mutter*) printf "%s\n" "/org/gnome/Mutter/DisplayConfig: org.gnome.Mutter.DisplayConfig.PropertiesChanged" \
    "/org/gnome/Mutter/DisplayConfig: org.gnome.Mutter.DisplayConfig.MonitorsChanged ()" ;;
  *NameHasOwner*) echo "(${T_OWNER:-true},)" ;;
esac'
fake udevadm 'printf "udevadm %s\n" "$*" >> "$T_LOG"
printf "%s\n" "UDEV  [1.0] add      /devices/pci0000:00/drm/card1 (drm)" "UDEV  [2.0] change   /devices/pci0000:00/drm/card1 (drm)"'
fake sudo 'printf "%s\n" "$*" >> "$T_LOG"
[[ "$*" != "semanage fcontext -l" ]] || printf "%s\n" "/data/Documents(/.*)?  all files  system_u:object_r:user_home_t:s0" "/home(/.*)?  directory  system_u:object_r:home_root_t:s0"'
fake xdg-user-dirs-update 'printf "xdg-user-dirs-update %s\n" "$*" >> "$T_LOG"'
for command in findmnt xdg-user-dir semanage restorecon drm_info nautilus; do fake "$command" ':'; done
fake lsblk 'if [[ "$*" == "-dn -o SERIAL "* ]]; then echo " FIXTURE123 "; else echo "nvme0n1 CT1000T705SSD3 FIXTURE123 1T nvme"; fi'
fake pgrep 'exit "${T_PGREP_RC:-1}"'
fake gdctl 'printf "%s\n" "Monitors:" "├──Monitor DP-1 (Fixture 27\")" "│  ├──Current mode" "│  │   └──${T_MODE:-2560x1440@239.970}" "│  └──${T_RGB:-rgb-range: full}"'
export PATH="$tmp/bin:$PATH"

# Fixture engine: deterministic runtime and hardware identity, clean journal.
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
hardware_b580_certified_connector() { echo /sys/class/drm/card1-DP-1; }
hardware_b580_expected_edid_sha256() { echo fixture-edid; }
kernel_journal_require_clean() { return 0; }
workstation_runtime_fingerprint() { echo fixture-fingerprint; }
SH
cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
log_info() { :; }
log_error() { :; }

# GNOME exposes minimize, maximize and close on the right, and proves it.
source "$fixture/modules/gnome/23_gnome_settings.sh"
REPORT_ROOT="$tmp/reports"; RUN_ID=fixture; mkdir -p "$REPORT_ROOT"
printf 'appmenu:close' > "$tmp/layout"
gnome_settings_precheck || fail 'GNOME precheck refused a session with the button-layout key'
rc=0; T_KEYS='' gnome_settings_precheck || rc=$?
[[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "missing button-layout key not refused (rc=$rc)"
rc=0; GNOME_WINDOW_BUTTON_LAYOUT='close,minimize:' gnome_settings_precheck || rc=$?
[[ "$rc" == "$EXIT_CONFIG_FAILED" ]] || fail "non-Golden window layout accepted (rc=$rc)"
rm -f "$T_LOG"
GNOME_WINDOW_BUTTONS_ENABLED=false gnome_settings_precheck
GNOME_WINDOW_BUTTONS_ENABLED=false DRY_RUN=false gnome_settings_apply
DRY_RUN=true gnome_settings_apply
[[ "$(cat "$tmp/layout")" == appmenu:close && ! -e "$T_LOG" ]] || fail 'window layout changed while disabled or in preflight'
DRY_RUN=false gnome_settings_apply
[[ "$(cat "$tmp/layout")" == ':minimize,maximize,close' ]] || fail "window layout not applied: $(cat "$tmp/layout")"
XDG_CURRENT_DESKTOP=GNOME DRY_RUN=false gnome_settings_postcheck || fail 'postcheck rejected the applied layout'
grep -Fxq "window-button-layout=':minimize,maximize,close'" "$REPORT_ROOT/fixture-gnome-font-settings.txt" \
  || fail 'postcheck did not record the window layout'
printf 'appmenu:close' > "$tmp/layout"
rc=0; XDG_CURRENT_DESKTOP=GNOME DRY_RUN=false gnome_settings_postcheck || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "drifted window layout passed the postcheck (rc=$rc)"

# Display watcher: sleep snapshots then restores, monitor and DRM changes only check.
state="$XDG_STATE_HOME/fedora-gnome-custom"
repair="$HOME/.local/libexec/fedora-gnome-display-repair"
mkdir -p "$(dirname "$repair")" "$state"
printf '#!/usr/bin/env bash\nprintf "repair %%s\\n" "$*" >> "$T_LOG"\n' > "$repair"
chmod +x "$repair"
watch() { # watch POLICY... : run the real watcher, print the repair calls
  rm -f "$T_LOG" "$state/display-repair-watch.log"
  printf '%s\n' "$@" > "$state/display-policy.env"
  bash "$fixture/scripts/gnome/display-watch.sh" || fail "display watcher failed for: $*"
  grep '^repair ' "$T_LOG" 2>/dev/null | paste -sd'|' || true
}
[[ "$(watch DISPLAY_REPAIR_ENABLED=true DISPLAY_REPAIR_ON_RESUME=true)" == 'repair --snapshot|repair --restore' ]] \
  || fail 'suspend/resume did not snapshot then restore'
grep -Eq 'reason=suspend rc=0$' "$state/display-repair-watch.log" && grep -Eq 'reason=resume rc=0$' "$state/display-repair-watch.log" \
  || fail 'watcher did not log the repair reason and result'
if grep -Fq Mutter "$T_LOG" || grep -Fq udevadm "$T_LOG"; then fail 'disabled watchers were started'; fi
[[ "$(watch DISPLAY_REPAIR_ENABLED=true DISPLAY_REPAIR_ON_MONITOR_CHANGE=true)" == 'repair --check' ]] \
  || fail 'Mutter MonitorsChanged must only check, once'
[[ "$(watch DISPLAY_REPAIR_ENABLED=true DISPLAY_REPAIR_ON_DRM_HOTPLUG=true)" == 'repair --check' ]] \
  || fail 'DRM change must only check, once'
grep -Fxq 'udevadm monitor --udev --subsystem-match=drm' "$T_LOG" || fail 'DRM watcher not limited to the drm subsystem'
for policy in 'DISPLAY_REPAIR_ENABLED=false DISPLAY_REPAIR_ON_RESUME=true' 'DISPLAY_REPAIR_ENABLED=true'; do
  read -r -a lines <<<"$policy"
  [[ -z "$(watch "${lines[@]}")" && ! -e "$T_LOG" ]] || fail "watcher acted with: $policy"
done
rm -f "$state/display-policy.env"
rc=0; bash "$fixture/scripts/gnome/display-watch.sh" 2>/dev/null || rc=$?
[[ "$rc" == 1 ]] || fail 'missing display policy not reported'

# /data layout: roots converged in place, persistent user_home_t labels, XDG Documents.
source "$fixture/modules/desktop/25_persistent_data.sh"
persistent_data_owner_user() { id -un; }
user="$(id -un)"; group="$(id -gn)"
rm -f "$T_LOG"; DRY_RUN=true desktop_persistent_data_apply
[[ ! -e "$T_LOG" ]] || fail "preflight /data apply ran: $(paste -sd'|' "$T_LOG")"
DRY_RUN=false desktop_persistent_data_apply || fail '/data apply failed'
for path in /data/Documents /data/Projets /data/ISO /data/Jeux /data/IA /data/IA/Openclaw; do
  verb=-a; [[ "$path" != /data/Documents ]] || verb=-m
  for call in "install -d $path" "chown $user:$group $path" "chmod 0750 $path" \
    "semanage fcontext $verb -t user_home_t $path(/.*)?" "restorecon -R $path"; do
    [[ "$(grep -Fxc -- "$call" "$T_LOG")" == 1 ]] || fail "/data apply did not run once: $call"
  done
done
grep -Eq 'xdg-user-dirs-update --set DOCUMENTS /data/Documents$' "$T_LOG" || fail 'XDG Documents not mapped to /data/Documents'
if grep -Eq '^(rm|mkfs|wipefs|parted|sgdisk)|ch(own|mod) -R|libvirt' "$T_LOG"; then fail "/data apply rewrote or destroyed data: $(paste -sd'|' "$T_LOG")"; fi
mkdir -p "$tmp/data/real"; ln -s "$tmp/data/real" "$tmp/data/link"
persistent_data_validate_mount() { [[ "${T_DATA:-valid}" == valid ]]; }
persistent_data_layout_paths() { printf '%s\n' "$tmp/data/real" ${T_EXTRA:+"$T_EXTRA"}; }
DRY_RUN=false desktop_persistent_data_precheck || fail '/data precheck refused a valid layout'
rc=0; T_DATA=invalid DRY_RUN=false desktop_persistent_data_precheck || rc=$?
[[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "unproven /data accepted (rc=$rc)"
rc=0; T_EXTRA="$tmp/data/link" DRY_RUN=false desktop_persistent_data_precheck || rc=$?
[[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "symlinked /data root accepted (rc=$rc)"

# Kickstart generator, run for real. Only the block-device and NVMe resolution
# probes are replaced; the serial comes from the fake lsblk.
generator="$fixture/installer/lib/generate-kickstart.sh"
sed -i -e 's/^\[\[ -b "\$disk" \]\]/[[ -n "$disk" ]]/' -e 's/^resolved="\$(readlink -f -- "\$disk")"$/resolved=\/dev\/nvme0n1/' "$generator"
grep -Fq '[[ -n "$disk" ]]' "$generator" && grep -Fxq 'resolved=/dev/nvme0n1' "$generator" || fail 'cannot neutralise the block-device probes'
git -C "$fixture" init -q && git -C "$fixture" add -A && git -C "$fixture" -c user.name=t -c user.email=t@t commit -qm fixture
sha="$(git -C "$fixture" rev-parse HEAD)"
disk=/dev/disk/by-id/nvme-CT1000T705SSD3_FIXTURE123
generate() { # generate ANSWERS [ARGS...]
  local answers="$1"; shift
  rm -f "$tmp/golden.ks"
  printf '%b' "$answers" | bash "$generator" --release 44 --disk "${T_DISK:-$disk}" --output "$tmp/golden.ks" "$@" > "$tmp/out" 2>&1
}
generate "EFFACER $disk\nS3cret-pass\nS3cret-pass\n" || { cat "$tmp/out" >&2; fail 'Kickstart generation failed'; }
grep -Fxq "Repository SHA pinned into Kickstart: $sha" "$tmp/out" || fail 'operator not shown the pinned SHA'
grep -Fxq "# Repository SHA: $sha" "$tmp/golden.ks" && grep -Fq "fetch --depth 1 origin $sha" "$tmp/golden.ks" \
  && grep -Fq "[[ \"\$actual_sha\" == \"$sha\" ]]" "$tmp/golden.ks" || fail 'Kickstart does not install the exact repository SHA'
grep -Fxq "[[ \"\$(lsblk -dn -o SERIAL '$disk' | xargs)\" == 'FIXTURE123' ]]" "$tmp/golden.ks" || fail 'Kickstart not bound to the disk serial'
[[ "$(stat -c %a "$tmp/golden.ks")" == 600 ]] || fail 'Kickstart with a password hash is not private'
if grep -Fq S3cret-pass "$tmp/golden.ks"; then fail 'clear-text password in the Kickstart'; fi
# The installed checkout selects the release the Kickstart was generated for.
grep -Fxq "printf 'HOST_RELEASE=\"44\"\\n' > \"\$repo/config/local.conf\"" "$tmp/golden.ks" || fail 'Fedora 44 Kickstart does not select HOST_RELEASE=44'
refused() { # refused WHY ANSWERS [ARGS...]
  local why="$1" rc=0; shift
  generate "$@" || rc=$?
  [[ "$rc" == 2 && ! -e "$tmp/golden.ks" ]] || fail "$why (rc=$rc)"
}
refused 'confirmation for another disk accepted' "EFFACER /dev/disk/by-id/nvme-OTHER\nS3cret-pass\nS3cret-pass\n"
refused 'lower-case confirmation accepted' "effacer $disk\nS3cret-pass\nS3cret-pass\n"
refused 'mismatched passwords accepted' "EFFACER $disk\nS3cret-pass\nother-pass\n"
refused 'empty password accepted' "EFFACER $disk\n\n\n"
refused 'invalid user name accepted' "EFFACER $disk\nS3cret-pass\nS3cret-pass\n" --username 'Root;x'
T_DISK="$disk-part1" refused 'partition target accepted' "EFFACER $disk-part1\np\np\n"
T_DISK=/dev/nvme0n1 refused 'unstable disk name accepted' "EFFACER /dev/nvme0n1\np\np\n"
ln -s "$tmp/elsewhere.ks" "$tmp/golden.ks.link"
rc=0; printf 'EFFACER %s\nS3cret-pass\nS3cret-pass\n' "$disk" | bash "$generator" --release 44 --disk "$disk" --output "$tmp/golden.ks.link" > "$tmp/out" 2>&1 || rc=$?
[[ "$rc" == 2 && ! -e "$tmp/elsewhere.ks" ]] && grep -Fq 'Refusing a symlinked output path' "$tmp/out" || fail "Kickstart written through a symlink (rc=$rc)"
rc=0; bash "$generator" --release 44 --disk "$disk" --output < /dev/null > "$tmp/out" 2>&1 || rc=$?
[[ "$rc" == 2 ]] && grep -Fq 'Missing value for --output.' "$tmp/out" || fail "option without a value not explained (rc=$rc)"
mv "$fixture/.git" "$tmp/git.off"
refused 'Kickstart generated outside a Git checkout' "EFFACER $disk\nS3cret-pass\nS3cret-pass\n"
mv "$tmp/git.off" "$fixture/.git"

# Display doctor: certified mode within the refresh tolerance, Wayland required.
doctor() { XDG_SESSION_TYPE="${T_SESSION:-wayland}" bash "$fixture/diagnostics/display-doctor" > "$tmp/out" 2>&1; }
doctor || { cat "$tmp/out" >&2; fail 'display doctor rejected 2560x1440@239.970 full RGB'; }
rc=0; T_MODE=2560x1440@143.998 doctor || rc=$?; [[ "$rc" != 0 ]] || fail '144 Hz passed the 240 Hz certification'
rc=0; T_MODE=1920x1080@239.970 doctor || rc=$?; [[ "$rc" != 0 ]] || fail 'wrong resolution passed'
rc=0; T_SESSION=x11 doctor || rc=$?; [[ "$rc" != 0 ]] || fail 'X11 session passed'
T_RGB='color-mode: default' doctor || fail 'unconfirmed RGB range must warn, not fail'
grep -Fq 'Full RGB not confirmed' "$tmp/out" || fail 'unconfirmed RGB range not reported'
printf 'DISPLAY_CERT_TOLERANCE_HZ="0.01"\n' > "$fixture/config/local.conf"
rc=0; doctor || rc=$?; [[ "$rc" != 0 ]] || fail 'refresh tolerance from the configuration ignored'
rm -f "$fixture/config/local.conf"

# Nautilus cold start: measured from a cold session, evidence only on bare metal.
nautilus_doctor() { bash "$fixture/diagnostics/nautilus-coldstart-doctor" --quiet > "$tmp/out" 2>&1 || { rc=$?; cat "$tmp/out" >&2; return $rc; }; }
evidence() { find "$tmp" -name nautilus-coldstart.ok -print -quit; }
rc=0; T_PGREP_RC=0 nautilus_doctor || rc=$?
[[ "$rc" == 2 && -z "$(evidence)" ]] || fail "warm Nautilus measured as a cold start (rc=$rc)"
T_RUNTIME=vm nautilus_doctor || fail 'cold start failed in a VM'
[[ -z "$(evidence)" ]] || fail 'VM cold start wrote bare-metal evidence'
nautilus_doctor || fail 'cold start failed'
[[ -n "$(evidence)" ]] && grep -Fxq fingerprint=fixture-fingerprint "$(evidence)" || fail 'bare-metal evidence missing its fingerprint'
rm -f "$(evidence)"
rc=0; T_OWNER=false nautilus_doctor || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" && -z "$(evidence)" ]] || fail "Nautilus without a D-Bus name passed (rc=$rc)"

echo 'golden workstation behavior: PASS'
