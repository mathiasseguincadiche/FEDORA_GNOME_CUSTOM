#!/usr/bin/env bash
# Physical runtime qualifications run for real in a repository copy: every new
# network or display attempt first removes its previous PASS evidence and the
# final certificate, so a failed re-run never leaves an old PASS behind; outside
# bare metal nothing is touched.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "physical attempt invalidation behavior: FAIL: $*" >&2; exit 1; }
fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home"
unset XDG_STATE_HOME XDG_CONFIG_HOME
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH
# NetworkManager inactive and no display doctor: each attempt fails right after it starts.
printf '#!/usr/bin/env bash\nexit 3\n' > "$tmp/bin/systemctl"; chmod +x "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/diagnostics/display-doctor"
export PATH="$tmp/bin:$PATH"
evidence="$fixture/state/final/evidence" cert="$fixture/state/final/certified.ok"
seed() { mkdir -p "$evidence"; printf 'status=PASS\n' | tee "$evidence/network-lan.ok" "$evidence/network-wifi.ok" "$evidence/display-capabilities.ok" > "$cert"; }
attempt() { local rc=0; env "$@" bash "$fixture/diagnostics/physical-runtime-doctor" "${ARGS[@]}" > "$tmp/out" 2>&1 || rc=$?; echo "$rc"; }
for case in 'network lan:network-lan' 'network wifi:network-wifi' 'display-capabilities:display-capabilities'; do
  read -r -a ARGS <<<"${case%%:*}"; name="${case##*:}"
  seed; rc="$(attempt)"
  [[ "$rc" != 0 && ! -e "$evidence/$name.ok" && ! -e "$cert" ]] || fail "${ARGS[*]}: failed attempt kept the previous PASS (rc=$rc)"
  seed; rc="$(attempt T_RUNTIME=vm)"
  [[ "$rc" == 50 && -s "$evidence/$name.ok" && -s "$cert" ]] || fail "${ARGS[*]}: a VM attempt changed the evidence (rc=$rc)"
done
# Baseline NVMe test: an attempt that stops after its gates removes the previous
# nvme evidence, the baseline certificate and the final certificate.
cat >> "$fixture/lib/persistent_data.sh" <<'SH'
persistent_data_validate_mount() { return 0; }
SH
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/mountpoint"; chmod +x "$tmp/bin/mountpoint"
baseline="$fixture/state/baseline"
for target in root data; do
  mkdir -p "$baseline/evidence"; seed
  printf 'status=PASS\n' | tee "$baseline/evidence/nvme-$target.ok" > "$baseline/certified.ok"
  rc=0; bash "$fixture/diagnostics/baseline-doctor" run-nvme-test "$target" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" != 0 && ! -e "$baseline/evidence/nvme-$target.ok" && ! -e "$baseline/certified.ok" && ! -e "$cert" ]] \
    || fail "nvme-$target: failed attempt kept the previous PASS (rc=$rc)"
  printf 'status=PASS\n' > "$baseline/evidence/nvme-$target.ok"
  rc=0; T_RUNTIME=vm bash "$fixture/diagnostics/baseline-doctor" run-nvme-test "$target" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == 50 && -s "$baseline/evidence/nvme-$target.ok" ]] || fail "nvme-$target: a VM attempt changed the evidence (rc=$rc)"
done
echo 'physical attempt invalidation behavior: PASS'
