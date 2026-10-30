#!/usr/bin/env bash
# Native validation run end to end through the real ./control.sh in a clean Git
# copy of the repository: a Live USB session records and exports its proof but
# can never reach an installed-system action; the installed system imports that
# proof, and Gate 3 runs its doctors only on the selected Fedora, from a clean
# checkout, with the current Live proof. The Live boot marker, os-release,
# preflight report and hardware identity are fixtures.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "validation entrypoints behavior: FAIL: $*" >&2; exit 1; }
source "$ROOT/lib/constants.sh"

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/usb"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp" FEDORA_OS_RELEASE_FILE="$tmp/os-release"
unset XDG_CONFIG_HOME XDG_STATE_HOME FEDORA_GNOME_CUSTOM_STATE_ROOT

# Host identities the engine reads become fixtures.
sed -i 's|cat /proc/cmdline|cat "$T_TMP/cmdline"|; s|-d /run/initramfs/live|-d "$T_TMP/run-initramfs-live"|' "$fixture/lib/common.sh"
grep -Fq 'cat "$T_TMP/cmdline"' "$fixture/lib/common.sh" || fail 'cannot redirect the Live boot marker'
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH
cat >> "$fixture/lib/validation_gates.sh" <<'SH'
validation_hardware_fingerprint() { printf '%064d\n' "${T_HARDWARE:-3}"; }
SH
# The Live preflight prints a complete report from the real catalog.
cat > "$fixture/diagnostics/live-preflight.sh" <<'SH'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/live_preflight_probe.sh"
printf 'live-preflight\n' >> "$T_LOG"
printf 'SCHEMA\tfgc-live-preflight\t2\nSTATUS\tCHECK\tDETAIL\n'
while IFS=$'\t' read -r id requirement evidence; do
  if [[ "$requirement" == required ]]; then status="${T_REQUIRED_STATUS:-PASS}"; else status=NOT_TESTED; fi
  printf '%s\t%s\trequirement=%s evidence=%s; fixture\n' "$status" "$id" "$requirement" "$evidence"
done < <(live_check_catalog)
printf 'SUMMARY\tFAIL=0\trequired NOT_TESTED=0\nDECISION\tGO\tpreinstallation only; installed system NOT_CERTIFIED\n'
exit "${T_PREFLIGHT_RC:-0}"
SH
# The real certification and release entrypoints stay callable under .real.
cp "$fixture/diagnostics/final-certification" "$fixture/diagnostics/final-certification.real"
cp "$fixture/scripts/release/capture-golden-release.sh" "$fixture/scripts/release/capture-golden-release.real.sh"
# Installed-system actions are recorders: a Live session must never reach them.
for tool in diagnostics/final-certification diagnostics/physical-runtime-doctor scripts/release/capture-golden-release.sh install.sh; do
  printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >> "$T_LOG"\n' "${tool##*/}" > "$fixture/$tool"
done
(cd "$fixture" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm fixture)
commit="$(git -C "$fixture" rev-parse HEAD)"
state="$fixture/state/validation"

os() { printf 'ID=fedora\nVERSION_ID=%s\n' "$1" > "$FEDORA_OS_RELEASE_FILE"; }
live() { printf 'BOOT_IMAGE=/images/pxeboot/vmlinuz root=live:CDLABEL=Fedora-WS-Live rd.live.image quiet\n' > "$tmp/cmdline"; }
installed() { printf 'BOOT_IMAGE=/vmlinuz root=UUID=1234 ro rhgb quiet\n' > "$tmp/cmdline"; }
control() { (cd "$fixture" && bash ./control.sh "$@") > "$tmp/out" 2>&1; }
refused() { # refused RC WHY ARGS... : control.sh must exit RC and reach no installed action
  local expected="$1" why="$2" rc=0; shift 2
  rm -f "$T_LOG"; control "$@" || rc=$?
  [[ "$rc" == "$expected" ]] || { cat "$tmp/out" >&2; fail "$why: expected rc=$expected, got $rc"; }
  ! grep -Eq '^(final-certification|physical-runtime-doctor|capture-golden-release.sh|install.sh) ' "$T_LOG" 2>/dev/null \
    || fail "$why reached an installed-system action: $(paste -sd'|' "$T_LOG")"
}
os 45; installed
real() { # real RC MESSAGE FILE ARGS... : the real entrypoint exits RC saying MESSAGE
  local expected="$1" message="$2" rc=0; shift 2
  (cd "$fixture" && bash "$@") > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == "$expected" ]] && grep -Fq "$message" "$tmp/out" || { cat "$tmp/out" >&2; fail "$* : expected rc=$expected with '$message', got $rc"; }
}

# Planning is read-only and works anywhere.
control validate live plan || fail 'Live plan failed'
grep -Eq '^session[[:space:]]+required' "$tmp/out" || fail 'Live plan lacks the check catalog'
[[ -z "$(git -C "$fixture" status --porcelain)" && ! -e "$state" ]] || fail 'Live plan wrote into the checkout'
control validate help && ! grep -Eqi 'wsl2|virtualbox|validate gate[12]' "$tmp/out" || fail 'validation help names a removed environment'
for gate in gate1 gate2; do refused "$EXIT_USAGE" "obsolete $gate accepted" validate "$gate" plan; done

# Live run: only in a native Live session, from a clean source.
refused "$EXIT_SECURITY_BLOCK" 'Live record from an installed system' validate live run
live
T_RUNTIME=vm refused "$EXIT_SECURITY_BLOCK" 'Live record from a VM' validate live run
mkdir -p "$state/outbox" "$state/imported"
touch "$state/outbox/live-$commit.json" "$state/imported/live.json"
touch "$fixture/stray.txt"
refused "$EXIT_SECURITY_BLOCK" 'Live record from a dirty source' validate live run
grep -Fxq live-preflight "$T_LOG" 2>/dev/null && fail 'Live preflight ran from a dirty source'
[[ ! -e "$state/outbox/live-$commit.json" && ! -e "$state/imported/live.json" ]] || fail 'stale proofs kept after a refused attempt'
rm "$fixture/stray.txt"
# Each native Live boot marker is recognised (the failed preflight proves the gate passed).
for marker in 'rd.live.image' 'root=live:CDLABEL=Fedora-WS-Live' initramfs; do
  installed
  if [[ "$marker" == initramfs ]]; then mkdir -p "$tmp/run-initramfs-live"; else printf 'BOOT_IMAGE=/vmlinuz %s quiet
' "$marker" > "$tmp/cmdline"; fi
  T_PREFLIGHT_RC=1 refused "$EXIT_PRECHECK_FAILED" "a failed Live preflight ($marker)" validate live run
  rm -rf "$tmp/run-initramfs-live"
done
live
T_PREFLIGHT_RC=1 refused "$EXIT_PRECHECK_FAILED" 'a failed Live preflight' validate live run
[[ ! -e "$state/outbox/live-$commit.json" ]] || fail 'proof written after a failed preflight'
[[ -s "$state/live-preflight.tsv" ]] || fail 'failed preflight report not kept for review'
T_REQUIRED_STATUS=NOT_TESTED refused "$EXIT_PRECHECK_FAILED" 'required Live checks not tested' validate live run
rm -f "$T_LOG"; control validate live run || { cat "$tmp/out" >&2; fail 'Live record refused on a clean Live session'; }
proof="$state/outbox/live-$commit.json"
[[ -s "$proof" && "$(stat -c %a "$proof")" == 600 ]] || fail 'Live proof missing or readable by others'
grep -Fq 'Save this JSON outside the Live HOME' "$tmp/out" || fail 'Live run does not tell the operator to save the proof'
[[ "$(paste -sd'|' "$T_LOG")" == live-preflight ]] || fail "Live run reached another action: $(paste -sd'|' "$T_LOG")"
control validate live status && grep -Fxq 'live_usb=PASS' "$tmp/out" || fail 'Live status does not see the record'
control validate status && grep -Fxq 'gate3_final=PENDING' "$tmp/out" || fail 'Live record claims installed certification'
control validate export live "$tmp/usb" || fail 'Live proof export failed'
cmp "$proof" "$tmp/usb/live-$commit.json" && (cd "$tmp/usb" && sha256sum --check --status "live-$commit.json.sha256") || fail 'exported proof differs'

# Gate 3 refuses a Live session before reaching any doctor.
real "$EXIT_SECURITY_BLOCK" 'Final certification is bare-metal only' diagnostics/final-certification.real certify
real "$EXIT_SECURITY_BLOCK" 'a Live session cannot certify installed services' scripts/release/capture-golden-release.real.sh
for command in status certify record-suspend gpu-soak network-lan physical-status; do
  refused "$EXIT_SECURITY_BLOCK" "Gate 3 $command from a Live session" validate gate3 "$command"
done

# Installed system: the proof is imported from the external support only when it matches.
installed; rm -rf "$fixture/state/validation"
refused "$EXIT_PRECHECK_FAILED" 'Gate 3 without the imported Live proof' validate gate3 status
real "$EXIT_PRECHECK_FAILED" 'requires a current native Live USB proof' diagnostics/final-certification.real certify
real "$EXIT_PRECHECK_FAILED" 'requires the current native Live USB proof' scripts/release/capture-golden-release.real.sh
T_HARDWARE=4 refused "$EXIT_SECURITY_BLOCK" 'a Live proof from another PC' validate import "$tmp/usb/live-$commit.json"
control validate import "$tmp/usb/live-$commit.json" || { cat "$tmp/out" >&2; fail 'matching Live proof not imported'; }
# A Live record attempted on the installed system never wipes the imported proof.
refused "$EXIT_SECURITY_BLOCK" 'Live record from the installed system' validate live run
[[ -s "$state/imported/live.json" ]] || fail 'installed system lost its imported Live proof'
cmp "$tmp/usb/live-$commit.json" "$state/imported/live.json" || fail 'imported proof differs'

# Fedora 45 is not promoted yet: Gate 3 refuses it; the selected promoted release runs.
refused "$EXIT_PRECHECK_FAILED" 'Gate 3 on an unpromoted Fedora 45' validate gate3 status
printf 'HOST_RELEASE="44"\n' > "$fixture/config/local.conf"; os 44
os 43; refused "$EXIT_PRECHECK_FAILED" 'Gate 3 on another Fedora release' validate gate3 status; os 44
printf 'ID=ubuntu\nVERSION_ID=44\n' > "$FEDORA_OS_RELEASE_FILE"; refused "$EXIT_PRECHECK_FAILED" 'Gate 3 on another distribution' validate gate3 status; os 44
T_RUNTIME=vm refused "$EXIT_SECURITY_BLOCK" 'Gate 3 in a VM' validate gate3 certify
# With the current Live proof, release capture moves on to the hardware baseline.
real "$EXIT_PRECHECK_FAILED" 'A valid hardware baseline is required' scripts/release/capture-golden-release.real.sh
touch "$fixture/stray.txt"; refused "$EXIT_SECURITY_BLOCK" 'Gate 3 from a dirty source' validate gate3 certify; rm "$fixture/stray.txt"
T_HARDWARE=4 refused "$EXIT_PRECHECK_FAILED" 'Gate 3 with the Live proof of another PC' validate gate3 certify
route() { # route ARGS... EXPECTED : the Gate 3 command reaches exactly EXPECTED
  local expected="${*: -1}"; rm -f "$T_LOG"
  control validate gate3 "${@:1:$#-1}" || { cat "$tmp/out" >&2; fail "Gate 3 ${*:1:$#-1} failed"; }
  [[ "$(paste -sd'|' "$T_LOG")" == "$expected" ]] || fail "Gate 3 ${*:1:$#-1} ran: $(paste -sd'|' "$T_LOG")"
}
route status 'physical-runtime-doctor status|final-certification status'
route certify 'final-certification certify'
route record-suspend 'final-certification record-suspend'
route gpu-soak 'physical-runtime-doctor gpu-soak'
route network-lan 'physical-runtime-doctor network lan'
route network-wifi 'physical-runtime-doctor network wifi'
route audio-cert 'physical-runtime-doctor audio'
route display-cert 'physical-runtime-doctor display-capabilities'
route physical-status 'physical-runtime-doctor status'
# A new commit makes the imported Live proof stale.
(cd "$fixture" && git -c user.name=t -c user.email=t@t commit -qm next --allow-empty)
refused "$EXIT_PRECHECK_FAILED" 'Gate 3 with the Live proof of another commit' validate gate3 certify

echo 'validation entrypoints behavior: PASS'
