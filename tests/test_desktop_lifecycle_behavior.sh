#!/usr/bin/env bash
# Desktop lifecycle run for real in a repository copy: the lifecycle module
# writes its DNF and dconf policy into a fixture /etc that the real
# lifecycle-doctor then audits, AppIndicator is installed and enabled through a
# fake gnome-extensions, each physical suspend cycle is recorded once and only
# when fresh, and the Arc compute doctor needs a real OpenCL run on bare metal.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "desktop lifecycle behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/sysroot/etc/dnf" "$tmp/var/suspend"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/home/.local/state" T_LOG="$tmp/calls" T_TMP="$tmp" T_SYSROOT="$tmp/sysroot"
unset XDG_CONFIG_HOME XDG_CURRENT_DESKTOP

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
# sudo runs install/systemctl with /etc mapped into the fixture root.
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"
args=(); for arg in "$@"; do [[ "$arg" != /etc/* ]] || arg="$T_SYSROOT$arg"; args+=("$arg"); done
case "$1" in
  install|systemctl) exec "${args[@]}" ;;
  dconf) [[ "$2" != update ]] || printf "compiled\n" > "$T_SYSROOT/etc/dconf/db/fgc" ;;
  dnf) ;;
  *) exit 99 ;;
esac'
fake systemctl 'case "$1" in
  enable) printf "%s\n" "$3" >> "$T_SYSROOT/enabled" ;;
  is-enabled) grep -Fxq "$3" "$T_SYSROOT/enabled" 2>/dev/null ;;
  list-unit-files) for unit in ${T_UNITS:-}; do [[ "$unit" != ${2//\*/}* ]] || echo "$unit enabled enabled"; done ;;
  *) exit 99 ;;
esac'
fake rpm 'for missing in ${T_MISSING:-}; do [[ "$2" != "$missing" ]] || exit 1; done'
fake gnome-extensions 'printf "gnome-extensions %s\n" "$*" >> "$T_LOG"
case "$1" in
  list) cat "$T_TMP/ext-visible" 2>/dev/null ;;
  info) grep -Fxq "$2" "$T_TMP/ext-active" 2>/dev/null && echo "  State: ACTIVE" || echo "  State: INACTIVE" ;;
  enable) printf "%s\n" "$2" >> "$T_TMP/ext-active" ;;
esac'
fake lspci 'exit "${T_GPU_RC:-0}"'
fake ldconfig 'echo "	libze_loader.so.1 (libc6,x86-64) => /usr/lib64/libze_loader.so.1"'
fake clinfo '[[ -n "${T_CLINFO_NONE:-}" ]] || echo "  Platform Name    Intel(R) OpenCL Graphics"
[[ -n "${T_CLINFO_NONE:-}${T_CLINFO_NO_DEVICE:-}" ]] || echo "  Device Name      Intel(R) Arc(TM) B580 Graphics"'
for command in dnf dnf5; do fake "$command" ':'; done
export PATH="$tmp/bin:$PATH"

# Fixture engine: deterministic runtime, identity and validation chain.
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
workstation_runtime_fingerprint() { echo "${T_FP:-fingerprint-1}"; }
hardware_b580_expected_edid_sha256() { echo fixture-edid; }
kernel_journal_require_clean() { return "${T_JOURNAL_RC:-0}"; }
SH
cat >> "$fixture/lib/validation_gates.sh" <<'SH'
validation_require_installed_runtime() { [[ "${T_RUNTIME:-baremetal}" == baremetal ]]; }
validation_require_imported_gate() { [[ -z "${T_NO_CHAIN:-}" ]]; }
validation_imported_proof_path() { echo "$T_TMP/live.json"; }
validation_final_certificate_valid() { return 1; }
SH
echo '{"proof": "fixture"}' > "$tmp/live.json"
# Every doctor final-certification delegates to is a recorder.
for doctor in "$fixture"/diagnostics/*; do
  case "${doctor##*/}" in final-certification|lifecycle-doctor|arc-compute-doctor) continue ;; esac
  printf '#!/usr/bin/env bash\nprintf "doctor %s %%s\\n" "$*" >> "$T_LOG"\nexit "${T_DOCTOR_RC:-0}"\n' "${doctor##*/}" > "$doctor"
done
printf 'import os, sys\nopen(os.environ["T_LOG"], "a").write("opencl-smoke\\n")\nsys.exit(int(os.environ.get("T_SMOKE_RC", "0")))\n' \
  > "$fixture/scripts/hardware/opencl-smoke.py"
# Host paths the engines hardcode point into the fixture root.
sed -i 's|^  profile=/etc/dconf/profile/user$|  profile="$T_SYSROOT/etc/dconf/profile/user"|' "$fixture/modules/desktop/27_lifecycle.sh"
sed -i 's|/etc/|${T_SYSROOT}/etc/|g' "$fixture/diagnostics/lifecycle-doctor"
sed -i 's|/var/lib/fedora-gnome-custom/suspend/latest-post.log|$T_TMP/var/suspend/latest-post.log|' "$fixture/diagnostics/final-certification"
grep -Fq 'profile="$T_SYSROOT' "$fixture/modules/desktop/27_lifecycle.sh" && grep -Fq '$T_TMP/var/suspend' "$fixture/diagnostics/final-certification" \
  || fail 'cannot redirect the hardcoded host paths'

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
source "$fixture/config/desktop.conf"
log_info() { :; }
log_error() { :; }

# Lifecycle policy: RPM updates downloaded, never installed or rebooted unattended.
source "$fixture/modules/desktop/27_lifecycle.sh"
desktop_lifecycle_precheck || fail 'lifecycle precheck refused the Golden policy'
for override in LIFECYCLE_AUTOMATIC_INSTALLS=true LIFECYCLE_AUTOMATIC_REBOOT=when-needed LIFECYCLE_FLATPAK_UPDATE_POLICY=automatic; do
  rc=0; env "$override" bash -c 'source "$1/lib/constants.sh"; source "$1/lib/common.sh"; log_error() { :; }; source "$1/modules/desktop/27_lifecycle.sh"; desktop_lifecycle_precheck' _ "$fixture" || rc=$?
  [[ "$rc" == "$EXIT_CONFIG_FAILED" ]] || fail "unsafe lifecycle policy accepted: $override (rc=$rc)"
done
mkdir -p "$T_SYSROOT/etc/dconf/profile"; printf 'user-db:user\nsystem-db:local\n' > "$T_SYSROOT/etc/dconf/profile/user"
DRY_RUN=true desktop_lifecycle_apply
[[ ! -e "$T_LOG" ]] || fail "preflight lifecycle apply ran: $(paste -sd'|' "$T_LOG")"
T_UNITS=fwupd-refresh.timer DRY_RUN=false desktop_lifecycle_apply || fail 'lifecycle apply failed'
conf="$T_SYSROOT/etc/dnf/automatic.conf"
for line in 'download_updates = true' 'apply_updates = false' 'reboot = never'; do
  grep -Fxq "$line" "$conf" || fail "automatic.conf lacks: $line"
done
[[ "$(paste -sd'|' "$T_SYSROOT/etc/dconf/profile/user")" == 'user-db:user|system-db:local||system-db:fgc' ]] \
  || fail "dconf profile not extended in place: $(paste -sd'|' "$T_SYSROOT/etc/dconf/profile/user")"
grep -Fxq 'allow-updates=false' "$T_SYSROOT/etc/dconf/db/fgc.d/00-updates" && grep -Fxq '/org/gnome/software/allow-updates' "$T_SYSROOT/etc/dconf/db/fgc.d/locks/updates" \
  || fail 'GNOME Software background updates not locked off'
[[ "$(paste -sd'|' "$T_SYSROOT/enabled")" == 'dnf5-automatic.timer|fstrim.timer|fwupd-refresh.timer' ]] \
  || fail "unexpected timers: $(paste -sd'|' "$T_SYSROOT/enabled")"
grep -Fxq 'sudo dconf update' "$T_LOG" || fail 'dconf database not rebuilt'
# Re-applying keeps a single fgc entry.
rm -f "$T_SYSROOT/enabled"; LIFECYCLE_ENABLE_FSTRIM=false DRY_RUN=false desktop_lifecycle_apply
[[ "$(grep -Fxc system-db:fgc "$T_SYSROOT/etc/dconf/profile/user")" == 1 ]] || fail 'dconf profile entry duplicated'
[[ "$(paste -sd'|' "$T_SYSROOT/enabled")" == dnf5-automatic.timer ]] || fail 'fstrim or fwupd enabled against the configuration'
T_UNITS=fwupd-refresh.timer DRY_RUN=false desktop_lifecycle_apply

lifecycle_doctor() { T_UNITS="fwupd-refresh.timer ${T_EXTRA_UNITS:-}" bash "$fixture/diagnostics/lifecycle-doctor" > "$tmp/out" 2>&1; }
lifecycle_doctor || { cat "$tmp/out" >&2; fail 'lifecycle doctor rejected the applied policy'; }
doctor_refuses() { # doctor_refuses WHY : the doctor must fail and say why
  local rc=0
  lifecycle_doctor || rc=$?
  [[ "$rc" != 0 ]] || fail "lifecycle doctor accepted: $1"
}
cp "$conf" "$tmp/conf.ok"
sed -i 's/^apply_updates = false$/apply_updates = true/' "$conf"; doctor_refuses 'unattended installs'
sed 's/^reboot = never$/reboot = when-needed/' "$tmp/conf.ok" > "$conf"; doctor_refuses 'unattended reboots'
cp "$tmp/conf.ok" "$conf"
T_EXTRA_UNITS=fedora-gnome-custom-flatpak-update.timer doctor_refuses 'a project-owned Flatpak updater'
grep -Fq 'unexpected project-owned unattended Flatpak updater exists' "$tmp/out" || fail 'Flatpak updater not reported'
T_MISSING=dnf5-plugin-automatic doctor_refuses 'a missing automatic plugin'
locks="$T_SYSROOT/etc/dconf/db/fgc.d/locks/updates"; cp "$locks" "$tmp/locks"
for key in download-updates allow-updates; do
  grep -Fxv "/org/gnome/software/$key" "$tmp/locks" > "$locks"; doctor_refuses "an unlocked GNOME Software $key"
done
cp "$tmp/locks" "$locks"
sed -i '/^fstrim.timer$/d' "$T_SYSROOT/enabled"; doctor_refuses 'a disabled fstrim timer'

# AppIndicator comes from the Fedora RPM and is enabled once in the session.
source "$fixture/config/gnome.conf"
source "$fixture/modules/gnome/24_gnome_extensions.sh"
ENABLE_DASH_TO_DOCK=false ENABLE_BLUR_MY_SHELL=false ENABLE_DESKTOP_ICONS_NG=false ENABLE_SHOW_DESKTOP_PLUS=false
INSTALL_EXTENSION_MANAGER=false HOST_RELEASE=44
install_manifest_packages() { printf 'packages %s\n' "${2##*/}" >> "$T_LOG"; }
uuid=appindicatorsupport@rgcjonas.gmail.com
[[ "$APPINDICATOR_UUID" == "$uuid" ]] || fail 'AppIndicator UUID changed'
grep -Fxq gnome-shell-extension-appindicator "$fixture/manifests/packages-gnome-extensions.txt" || fail 'AppIndicator RPM not in the manifest'
gnome_extensions_precheck || fail 'extension precheck refused AppIndicator'
for override in APPINDICATOR_UUID=appindicator@evil APPINDICATOR_PACKAGE=gnome-shell-extension-other; do
  rc=0; (eval "$override"; gnome_extensions_precheck) || rc=$?
  [[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "AppIndicator from another source accepted: $override (rc=$rc)"
done
rm -f "$T_LOG"
rc=0; DRY_RUN=false gnome_extensions_apply || rc=$?
[[ "$rc" == "$EXIT_APPLY_FAILED" ]] || fail "AppIndicator enabled while the session cannot see it (rc=$rc)"
grep -Fxq 'packages packages-gnome-extensions.txt' "$T_LOG" || fail 'extension RPMs not installed'
if grep -Fq 'gnome-extensions enable' "$T_LOG"; then fail 'invisible extension enabled'; fi
echo "$uuid" > "$tmp/ext-visible"
DRY_RUN=false gnome_extensions_apply || fail 'AppIndicator apply failed'
DRY_RUN=false gnome_extensions_apply || fail 'AppIndicator re-apply failed'
[[ "$(grep -Fxc "gnome-extensions enable $uuid" "$T_LOG")" == 1 ]] || fail 'AppIndicator not enabled exactly once'
DRY_RUN=false gnome_extensions_postcheck || fail 'active AppIndicator failed the postcheck'
rc=0; T_MISSING=gnome-shell-extension-appindicator DRY_RUN=false gnome_extensions_postcheck || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "AppIndicator without its RPM passed (rc=$rc)"
: > "$tmp/ext-active"
rc=0; DRY_RUN=false gnome_extensions_postcheck || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "inactive AppIndicator passed (rc=$rc)"

# Physical suspend cycles: one fresh record per post-resume log, after the display repair.
marker="$HOME/.local/state/fedora-gnome-custom/display-repair-last.txt"
mkdir -p "$(dirname "$marker")"
now="$(date +%s)"
resume() { # resume NAME POST_AGE MARKER_AGE : a new physical resume cycle
  printf 'post-resume %s\n' "$1" > "$tmp/var/suspend/$1.log"
  ln -sfn "$tmp/var/suspend/$1.log" "$tmp/var/suspend/latest-post.log"
  touch -d "@$((now - $2))" "$tmp/var/suspend/$1.log"
  printf 'edid_sha256=fixture-edid\n' > "$marker"; touch -d "@$((now - $3))" "$marker"
}
record() { rm -f "$T_LOG"; bash "$fixture/diagnostics/final-certification" record-suspend > "$tmp/out" 2>&1; }
evidence_count() { { find "$fixture/state/final/evidence" -name 'suspend-*.ok' 2>/dev/null || true; } | wc -l; }
unique_cycles() { bash "$fixture/diagnostics/final-certification" status 2>/dev/null | sed -n 's/^Unique suspend PASS cycles: *//p'; }
rejected() { # rejected WHY : record-suspend refuses and writes no evidence
  local before rc=0
  before="$(evidence_count)"
  record || rc=$?
  [[ "$rc" != 0 && "$(evidence_count)" == "$before" ]] || fail "$1 (rc=$rc)"
}
rejected 'cycle recorded without post-resume evidence'
grep -Fq 'No physical post-resume sleep-hook evidence' "$tmp/out" || fail 'missing post-resume evidence not reported'
resume cycle-1 20 10
record || { cat "$tmp/out" >&2; fail 'fresh suspend cycle refused'; }
for doctor in kernel-doctor graphics-doctor display-doctor storage-doctor usb-resume-doctor performance-doctor; do
  grep -q "^doctor $doctor " "$T_LOG" || fail "suspend cycle recorded without $doctor"
done
cycle="$(printf '%s\n' cycle-1.log | sha256sum | cut -d' ' -f1)"
evidence="$fixture/state/final/evidence/suspend-$cycle.ok"
grep -Fxq "cycle_id=$cycle" "$evidence" && grep -Fxq fingerprint=fingerprint-1 "$evidence" || fail 'suspend evidence lacks its cycle or fingerprint'
[[ "$(stat -c %a "$evidence")" == 600 ]] || fail 'suspend evidence is not private'
[[ "$(unique_cycles)" == '1 / 5' ]] || fail "unexpected cycle count: $(unique_cycles)"
rejected 'the same physical cycle was recorded twice'
grep -Fq 'This physical suspend/resume cycle is already recorded' "$tmp/out" || fail 'duplicate cycle not reported'
cp "$evidence" "$fixture/state/final/evidence/suspend-copy.ok"
[[ "$(unique_cycles)" == '1 / 5' ]] || fail 'a copied evidence file counted as a new cycle'
rm "$fixture/state/final/evidence/suspend-copy.ok"
resume cycle-2 20 30; rejected 'display repair from before the resume accepted'
resume cycle-2 700 10; rejected 'stale post-resume evidence accepted'
resume cycle-2 400 350; rejected 'stale display repair marker accepted'
resume cycle-2 20 10
T_JOURNAL_RC=1 rejected 'cycle with critical kernel signals accepted'
T_DOCTOR_RC=1 rejected 'cycle with a failing doctor accepted'
T_RUNTIME=vm rejected 'cycle recorded outside bare metal'
T_NO_CHAIN=1 rejected 'cycle recorded without the Live USB proof'
record || fail 'second fresh cycle refused'
[[ "$(unique_cycles)" == '2 / 5' ]] || fail "second cycle not counted: $(unique_cycles)"
[[ "$(T_FP=fingerprint-2 unique_cycles)" == '0 / 5' ]] || fail 'cycles from another runtime stack still count'

# A certification attempt that fails never leaves a previous certificate behind;
# a refused runtime (VM, no Live proof) does not touch it.
cert="$fixture/state/final/certified.ok"
certify() { rm -f "$T_LOG"; env "$@" bash "$fixture/diagnostics/final-certification" certify > "$tmp/out" 2>&1; }
printf 'verdict=PASS
previous=1
' > "$cert"
rc=0; certify T_RUNTIME=vm || rc=$?
[[ "$rc" == 50 && -s "$cert" ]] || fail "VM certification attempt changed the certificate (rc=$rc)"
rc=0; certify T_NO_CHAIN=1 || rc=$?
[[ "$rc" == 20 && -s "$cert" ]] || fail "certification without the Live proof changed the certificate (rc=$rc)"
rc=0; certify || rc=$?
[[ "$rc" != 0 && ! -e "$cert" ]] || fail "failed certification attempt kept the previous certificate (rc=$rc)"

# Arc compute: packages, Level Zero, an enumerated Intel OpenCL device, a real run on bare metal.
arc() { rm -f "$T_LOG"; bash "$fixture/diagnostics/arc-compute-doctor" > "$tmp/out" 2>&1; }
arc || { cat "$tmp/out" >&2; fail 'Arc compute doctor rejected a complete stack'; }
grep -Fxq opencl-smoke "$T_LOG" || fail 'bare-metal Arc compute passed without a real OpenCL run'
T_RUNTIME=vm arc || fail 'Arc compute doctor failed in a VM'
[[ ! -e "$T_LOG" ]] && grep -Fq 'real GPU execution deferred outside bare-metal' "$tmp/out" || fail 'OpenCL run not deferred in a VM'
for case in T_SMOKE_RC=1 T_CLINFO_NONE=1 T_CLINFO_NO_DEVICE=1 T_GPU_RC=1 T_MISSING=intel-level-zero T_MISSING=clinfo; do
  rc=0; env "$case" bash "$fixture/diagnostics/arc-compute-doctor" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" != 0 ]] || fail "Arc compute doctor passed with $case"
done

echo 'desktop lifecycle behavior: PASS'
