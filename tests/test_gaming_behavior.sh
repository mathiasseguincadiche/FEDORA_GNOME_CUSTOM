#!/usr/bin/env bash
# Gaming profile run for real in a repository copy with fake dnf/rpm and game
# tools: the stack stays off unless configured, Steam only comes from the
# Fedora-defined RPM Fusion Steam channel, the library lives on /data/Jeux, and
# the gaming doctor certifies the Arc renderer and display on bare metal only.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015,SC2163
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "gaming behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/data/Jeux" "$tmp/root/usr/share/dnf5/repos.d"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp"
unset XDG_CONFIG_HOME XDG_STATE_HOME
printf '[rpmfusion-nonfree-steam]\nenabled=0\n' > "$tmp/root/usr/share/dnf5/repos.d/rpmfusion-nonfree-steam.repo"

# The Steam repository lookup reads the host root; point it at the fixture root.
for file in modules/gaming/43_gaming_stack.sh diagnostics/gaming-doctor; do
  sed -i 's|gaming_steam_repository_file /|gaming_steam_repository_file "$T_TMP/root"|' "$fixture/$file"
  grep -Fq 'gaming_steam_repository_file "$T_TMP/root"' "$fixture/$file" || fail "cannot redirect the Steam repository lookup in $file"
done
cat >> "$fixture/lib/persistent_data.sh" <<'SH'
persistent_data_mount() { printf '%s\n' "$T_TMP/data"; }
persistent_data_validate_mount() { [[ "${T_DATA:-valid}" == valid ]]; }
SH
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH
for doctor in graphics-doctor display-doctor; do
  printf '#!/usr/bin/env bash\nprintf "doctor %s\\n" >> "$T_LOG"\nexit "${T_DOCTOR_RC:-0}"\n' "$doctor" > "$fixture/diagnostics/$doctor"
done

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"'
fake dnf '[[ "$1" == repolist ]] || exit 99
printf "%s\n" "fedora Fedora 45" "rpmfusion-nonfree RPM Fusion nonfree" ${T_NO_STEAM_REPO:+} ${T_EXTRA_REPO:+"$T_EXTRA_REPO"}
[[ -n "${T_NO_STEAM_REPO:-}" ]] || echo "rpmfusion-nonfree-steam RPM Fusion Steam"'
# rpm: every package installed except T_MISSING; files belong to T_OWNER (default per path).
fake rpm 'if [[ "$1" == -qf ]]; then
  file="${@: -1}"
  case "$file" in
    *rpmfusion-nonfree-steam.repo) echo "${T_REPO_OWNER:-fedora-workstation-repositories}" ;;
    */steam) [[ -z "${T_STEAM_UNOWNED:-}" ]] || exit 1; echo steam ;;
    *) echo owner ;;
  esac
  exit 0
fi
shift
for pkg; do for missing in ${T_MISSING:-}; do [[ "$pkg" != "$missing" ]] || exit 1; done; done'
for command in steam gamemoderun mangohud gamescope goverlay; do fake "$command" ':'; done
fake vulkaninfo 'echo "deviceName = ${T_VULKAN:-Intel(R) Arc(tm) B580 Graphics (BMG G21)}"'
fake gdctl 'echo "Monitor DP-1: ${T_VRR:-VRR: supported}"'
export PATH="$tmp/bin:$PATH"

cd "$fixture"
REPO_ROOT="$fixture"
source "$fixture/lib/bootstrap.sh"
engine_load_libraries
log_info() { :; }; log_error() { :; }
install_manifest_packages() { printf 'packages %s\n' "${2##*/}" >> "$T_LOG"; }
source "$fixture/modules/gaming/43_gaming_stack.sh"
source "$fixture/modules/gaming/44_gaming_validation.sh"

# Without configuration the profile is off: nothing installed, nothing checked.
rm -f "$T_LOG"
(unset GAMING_ENABLE; gaming_stack_precheck && DRY_RUN=false gaming_stack_apply && DRY_RUN=false gaming_stack_postcheck && DRY_RUN=false gaming_validation_postcheck) \
  || fail 'unconfigured gaming profile was not a no-op'
[[ ! -e "$T_LOG" ]] || fail "unconfigured gaming profile ran: $(paste -sd'|' "$T_LOG")"
source "$fixture/config/gaming.conf"
[[ "$GAMING_ENABLE" == true ]] || fail 'Golden profile must enable gaming'

# Precheck: RPM Fusion and an x86_64 host, plus a writable /data/Jeux before APPLY.
gaming_stack_precheck || fail 'gaming precheck refused the Golden host'
DRY_RUN=false gaming_stack_precheck || fail 'gaming APPLY precheck refused a writable /data/Jeux'
refused() { local why="$1" rc=0; shift; (for var; do export "$var"; done; gaming_stack_precheck) || rc=$?; [[ "$rc" == "$EXIT_PRECHECK_FAILED" ]] || fail "gaming precheck accepted $why (rc=$rc)"; }
refused 'RPM Fusion disabled' ENABLE_RPMFUSION=false
refused 'an unproven /data' DRY_RUN=false T_DATA=invalid
mv "$tmp/data/Jeux" "$tmp/Jeux.off"; refused 'a missing /data/Jeux' DRY_RUN=false; mv "$tmp/Jeux.off" "$tmp/data/Jeux"
fake uname '[[ "$1" == -m ]] && echo aarch64 || command -p uname "$@"'
refused 'a non-x86_64 host'
rm "$tmp/bin/uname"

# Apply: Fedora packages, Fedora's Steam repository definition, Steam from that channel only.
rm -f "$T_LOG"; DRY_RUN=true gaming_stack_apply
[[ "$(paste -sd'|' "$T_LOG")" == 'packages packages-gaming.txt' ]] || fail "preflight gaming apply ran: $(paste -sd'|' "$T_LOG")"
rm -f "$T_LOG"; DRY_RUN=false gaming_stack_apply || fail 'gaming apply failed'
[[ "$(paste -sd'|' "$T_LOG")" == 'packages packages-gaming.txt|sudo dnf -y install fedora-workstation-repositories|sudo dnf -y --enablerepo=rpmfusion-nonfree-steam install steam' ]] \
  || fail "unexpected gaming apply: $(paste -sd'|' "$T_LOG")"
apply_refused() {
  local why="$1" rc=0; shift
  rm -f "$T_LOG"; (for var; do export "$var"; done; DRY_RUN=false gaming_stack_apply) || rc=$?
  [[ "$rc" == "$EXIT_APPLY_FAILED" ]] && ! grep -q 'install steam' "$T_LOG" || fail "Steam installed with $why (rc=$rc)"
}
apply_refused 'a repository definition from another package' T_REPO_OWNER=rpmfusion-nonfree-release
apply_refused 'the Steam channel missing from dnf' T_NO_STEAM_REPO=1
mv "$tmp/root/usr/share/dnf5/repos.d/rpmfusion-nonfree-steam.repo" "$tmp/steam.repo"
apply_refused 'no Steam repository definition'
mkdir -p "$tmp/root/etc/yum.repos.d"; mv "$tmp/steam.repo" "$tmp/root/etc/yum.repos.d/rpmfusion-nonfree-steam.repo"
DRY_RUN=false gaming_stack_apply || fail 'legacy /etc Steam repository definition refused'

# Postcheck: every RPM, native commands, an RPM-owned Steam, a writable library.
DRY_RUN=false gaming_stack_postcheck || fail 'complete gaming stack refused'
post_refused() { local why="$1" rc=0; shift; (for var; do export "$var"; done; DRY_RUN=false gaming_stack_postcheck) || rc=$?; [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "gaming postcheck accepted $why (rc=$rc)"; }
post_refused 'missing Steam' T_MISSING=steam
post_refused 'missing 32-bit Mesa Vulkan' T_MISSING=mesa-vulkan-drivers.i686
post_refused 'missing 32-bit Vulkan loader' T_MISSING=vulkan-loader.i686
post_refused 'a Steam command outside RPM' T_STEAM_UNOWNED=1
chmod a-w "$tmp/data/Jeux"
if [[ ! -w "$tmp/data/Jeux" ]]; then post_refused 'a read-only /data/Jeux'; fi
chmod u+w "$tmp/data/Jeux"
mv "$tmp/bin/gamescope" "$tmp/gamescope.off"; post_refused 'missing gamescope'; mv "$tmp/gamescope.off" "$tmp/bin/gamescope"

# Gaming doctor.
doctor() { rm -f "$T_LOG"; env "$@" bash diagnostics/gaming-doctor > "$tmp/out" 2>&1; }
doctor || { cat "$tmp/out" >&2; fail 'healthy gaming stack refused'; }
grep -Fxq 'doctor graphics-doctor' "$T_LOG" && grep -Fxq 'doctor display-doctor' "$T_LOG" || fail 'bare-metal gaming skipped the Arc or display doctor'
grep -Fq 'not initialized yet' "$tmp/out" || fail 'missing Proton not reported'
mkdir -p "$tmp/data/Jeux/steamapps/common/Proton 9.0"
doctor && grep -Fq 'Steam-managed Proton payload detected' "$tmp/out" || fail 'Proton in the /data/Jeux library not found'
blocked() { local why="$1" rc=0; shift; doctor "$@" || rc=$?; [[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]] || fail "gaming doctor accepted $why (rc=$rc)"; }
blocked 'a failing Arc graphics doctor' T_DOCTOR_RC=1
blocked 'a non-Arc Vulkan renderer' 'T_VULKAN=llvmpipe (LLVM 19.1.0, 256 bits)'
blocked 'a third-party Mesa repository' 'T_EXTRA_REPO=copr:copr.fedorainfracloud.org:xxmitsu:mesa-git'
blocked 'missing 32-bit Mesa DRI' T_MISSING=mesa-dri-drivers.i686
blocked 'missing steam-devices' T_MISSING=steam-devices
blocked 'a Steam command outside RPM' T_STEAM_UNOWNED=1
blocked 'an unproven /data' T_DATA=invalid
T_VRR='no adaptive information' doctor && grep -Fq 'does not expose an explicit VRR state' "$tmp/out" || fail 'unknown VRR must only warn'
doctor T_RUNTIME=vm 'T_VULKAN=llvmpipe' || fail 'VM gaming stack refused for the bare-metal-only checks'
[[ ! -e "$T_LOG" ]] && grep -Fq 'intentionally not certified here' "$tmp/out" || fail 'VM ran the bare-metal GPU checks'
printf 'GAMING_ENABLE="false"\n' > config/local.conf
doctor T_MISSING=steam || fail 'disabled gaming profile still audited'
DRY_RUN=false GAMING_ENABLE=false gaming_validation_postcheck || fail 'disabled gaming validation ran'
rm config/local.conf

echo 'gaming behavior: PASS'
