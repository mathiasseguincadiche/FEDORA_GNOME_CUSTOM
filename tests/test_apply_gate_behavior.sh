#!/usr/bin/env bash
# Behavioral test of the REAL APPLY gate (lib/apply_gate.sh), executed in a
# real pseudo-terminal (util-linux `script`). Every precondition must block on
# its own with EXIT_SECURITY_BLOCK and a message naming it; the dry-run proof is
# checked with the real evidence library (commit, config, plan and hardware).
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v script >/dev/null || { echo 'script (util-linux) required' >&2; exit 20; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "apply gate behavior: FAIL: $*" >&2; exit 1; }

cat > "$tmp/driver.sh" <<'DRIVER'
set -Eeuo pipefail
ROOT="$1"; STATE_ROOT="$2"; REPO_ROOT="$ROOT"; RUN_ID=test
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/evidence.sh"
is_true() { [[ "${1,,}" == true ]]; }
ui_error() { printf 'GATE-ERROR: %s\n' "$*"; }
runtime_environment() { printf '%s\n' "${T_RUNTIME:-baremetal}"; }
runtime_is_baremetal() { [[ "${T_RUNTIME:-baremetal}" == baremetal ]]; }
runtime_is_live() { [[ "${T_LIVE:-false}" == true ]]; }
repo_commit() { printf '%s\n' "${T_COMMIT:-1111111111111111111111111111111111111111}"; }
effective_config_sha256() { printf '%s\n' "${T_CONFIG:-aaaa}"; }
module_plan_sha256() { printf 'bbbb\n'; }
baseline_fingerprint() { printf '%s\n' "${T_HARDWARE-hw-1}"; }
source "$ROOT/lib/apply_gate.sh"
# Only this prerequisite is simulated to exercise the other gate stages.
# Actual target/profile/os-release selection is tested in test_fedora_release_behavior.sh.
fedora_require_install_target() { [[ "${T_TARGET_READY:-true}" == true ]]; }
# Git and the two heavier proofs are isolated here; the dry-run proof is real.
apply_gate_require_clean_git() { [[ "${T_CLEAN:-true}" == true ]]; }
apply_gate_require_baseline() { [[ "${T_BASELINE:-true}" == true ]]; }
apply_gate_require_backup() { [[ "${T_BACKUP:-true}" == true ]]; }
REAL_APPLY_FEATURE_ENABLED="${T_FEATURE:-true}"
REAL_MACHINE_APPROVED="${T_APPROVED:-true}"
APPLY_CONFIRMATION="${T_PHRASE-APPLY FEDORA 45 WORKSTATION}"
if [[ "${T_WRITE_PROOF:-false}" == true ]]; then apply_gate_write_dryrun_proof; exit 0; fi
rc=0; apply_gate_open || rc=$?
printf '\nGATE-RC=%s\n' "$rc"
DRIVER

state="$tmp/state"
run_gate() {   # run_gate <stdin answer> [VAR=value...] -> output in $out
  local answer="$1"; shift
  out="$(printf '%s\n' "$answer" | env "$@" script -qec "bash '$tmp/driver.sh' '$ROOT' '$state'" /dev/null 2>&1 | tr -d '\r')"
}
expect_block() {   # expect_block <message fragment> [VAR=value...]
  local fragment="$1"; shift
  run_gate 'APPLY FEDORA 45 WORKSTATION' "$@"
  grep -Fq 'GATE-RC=50' <<<"$out" || fail "not blocked ($*): $out"
  grep -Fq "$fragment" <<<"$out" || fail "blocked for the wrong reason ($*), expected '$fragment': $out"
}

# The valid dry-run proof for the current identity (written by the real code).
env T_WRITE_PROOF=true bash "$tmp/driver.sh" "$ROOT" "$state"
[[ -s "$state/dryrun-1111111111111111111111111111111111111111.ok" ]] || fail 'dry-run proof not written'

# 1. Every precondition blocks on its own, with its own message.
expect_block 'forbidden outside bare-metal' T_RUNTIME=vm
expect_block 'Production APPLY requires running Fedora 45' T_TARGET_READY=false
expect_block 'REAL APPLY feature disabled' T_FEATURE=false
expect_block 'REAL_MACHINE_APPROVED=false' T_APPROVED=false
expect_block 'Git working tree must be clean' T_CLEAN=false
expect_block 'hardware baseline certification missing' T_BASELINE=false
expect_block 'pre-APPLY Borg archive is missing' T_BACKUP=false

# 2. The real dry-run proof is bound to commit, configuration and hardware.
expect_block 'dry-run proof is missing/stale' T_COMMIT=2222222222222222222222222222222222222222
expect_block 'dry-run proof is missing/stale' T_CONFIG=changed
expect_block 'dry-run proof is missing/stale' T_HARDWARE=hw-2

# 3. No terminal, no APPLY (e.g. a cron job or a pipe).
out="$(printf 'APPLY FEDORA 45 WORKSTATION\n' | bash "$tmp/driver.sh" "$ROOT" "$state" 2>&1)"
grep -Fq 'GATE-RC=50' <<<"$out" || fail "non-interactive APPLY not refused: $out"
grep -Fq 'interactive TTY required' <<<"$out" || fail "non-interactive APPLY refused for the wrong reason: $out"

# 4. Everything valid: only the exact typed phrase opens the gate.
run_gate 'APPLY FEDORA 44 WORKSTATION'
grep -Fq 'GATE-RC=50' <<<"$out" || fail "historic Fedora 44 confirmation accepted: $out"
run_gate 'apply fedora 45 workstation'
grep -Fq 'GATE-RC=50' <<<"$out" || fail "approximate confirmation accepted: $out"
run_gate 'APPLY FEDORA 45 WORKSTATION'
grep -Fq 'GATE-RC=0' <<<"$out" || fail "valid APPLY refused: $out"

expect_block 'Live USB session' T_LIVE=true

# 5. An emptied confirmation phrase never accepts an empty answer.
run_gate '' T_PHRASE=
if ! grep -Fq 'GATE-RC=50' <<<"$out" || ! grep -Fq 'APPLY_CONFIRMATION is empty' <<<"$out"; then fail "empty confirmation phrase accepted: $out"; fi

# 6. A proof written outside Git (commit "unknown") or without a hardware
# fingerprint (unreadable baseline) is no current identity, even when the
# current state is equally unknown.
env T_WRITE_PROOF=true T_COMMIT=unknown bash "$tmp/driver.sh" "$ROOT" "$state"
expect_block 'dry-run proof is missing/stale' T_COMMIT=unknown
env T_WRITE_PROOF=true T_HARDWARE= bash "$tmp/driver.sh" "$ROOT" "$state"
expect_block 'dry-run proof is missing/stale' T_HARDWARE=

# 7. The real clean-tree check: a Git failure is never a clean tree.
clean_git() { (REPO_ROOT="$1"; is_true() { [[ "${1,,}" == true ]]; }; source "$ROOT/lib/apply_gate.sh"; apply_gate_require_clean_git) 2>/dev/null; }
mkdir -p "$tmp/not-a-checkout" "$tmp/checkout"
if clean_git "$tmp/not-a-checkout"; then fail 'a directory outside Git passed the clean-tree check'; fi
git -C "$tmp/checkout" init -q
printf 'x\n' > "$tmp/checkout/tracked"
git -C "$tmp/checkout" add tracked && git -C "$tmp/checkout" -c user.name=t -c user.email=t@t commit -qm init
clean_git "$tmp/checkout" || fail 'a clean checkout failed the clean-tree check'
printf 'y\n' >> "$tmp/checkout/tracked"
if clean_git "$tmp/checkout"; then fail 'a modified checkout passed the clean-tree check'; fi

echo 'apply gate behavior: PASS'
