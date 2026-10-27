#!/usr/bin/env bash
# Real Live proof serialization/import/export on disposable files. Runtime,
# source and hardware callbacks are fixtures; no host hardware is inspected.
# shellcheck disable=SC2034,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT
fail() { echo "Live proof behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$fixture_root/repo/lib" "$fixture_root/repo/manifests"
cp "$ROOT/lib/live_validation.py" "$ROOT/lib/live_preflight_probe.sh" "$fixture_root/repo/lib/"
printf 'fixture.preflight|SYSTEM||modules/preflight.sh\n' > "$fixture_root/repo/manifests/module-plan.conf"
cp "$fixture_root/repo/manifests/module-plan.conf" "$fixture_root/original-plan"

(
  REPO_ROOT="$fixture_root/repo"
  STATE_ROOT="$fixture_root/live-state"
  RUNTIME_ENVIRONMENT=baremetal
  FIXTURE_LIVE=true
  FIXTURE_CLEAN=true
  FIXTURE_COMMIT=1111111111111111111111111111111111111111
  FIXTURE_HARDWARE=3333333333333333333333333333333333333333333333333333333333333333
  FIXTURE_KERNEL='7.1.8-live.fc45.x86_64'
  FIXTURE_FAIL_WRITE=''
  FIXTURE_FAIL_HASH=''
  FIXTURE_CAT_FAIL=false
  FIXTURE_INSTALL_FAIL=false
  source "$ROOT/lib/constants.sh"
  source "$ROOT/lib/evidence.sh"
  source "$ROOT/lib/validation_gates.sh"

  repo_commit() { printf '%s\n' "$FIXTURE_COMMIT"; }
  runtime_environment() { printf '%s\n' "$RUNTIME_ENVIRONMENT"; }
  runtime_is_baremetal() { [[ "$RUNTIME_ENVIRONMENT" == baremetal ]]; }
  # Override after source: these tests never infer a Live boot from the host.
  validation_runtime_is_live() { [[ "$FIXTURE_LIVE" == true ]]; }
  validation_hardware_fingerprint() { printf '%s\n' "$FIXTURE_HARDWARE"; }
  validation_source_is_clean() { [[ "$FIXTURE_CLEAN" == true ]]; }
  ui_error() { printf 'ERROR: %s\n' "$*" >&2; }
  uname() { [[ "$*" == -r ]] || return 98; printf '%s\n' "$FIXTURE_KERNEL"; }
  # shellcheck disable=SC2120
  cat() {
    if [[ "$FIXTURE_CAT_FAIL" == true ]]; then
      printf 'truncated fixture stream'
      return 37
    fi
    command cat "$@"
  }
  install() {
    [[ "$FIXTURE_INSTALL_FAIL" != true ]] || return 37
    command install "$@"
  }
  # Keep the actual atomic writer for normal paths and inject a precise failure
  # for the selected artifact. This also works when the runner itself is root.
  eval "$(declare -f evidence_atomic_write | sed '1s/evidence_atomic_write/fixture_atomic_write/')"
  evidence_atomic_write() {
    [[ "$1" != "$FIXTURE_FAIL_WRITE" ]] || return 37
    fixture_atomic_write "$@"
  }
  eval "$(declare -f validation_file_sha256 | sed '1s/validation_file_sha256/fixture_file_sha256/')"
  validation_file_sha256() {
    [[ "$1" != "$FIXTURE_FAIL_HASH" ]] || return 37
    fixture_file_sha256 "$@"
  }
  assert_fails() {
    local label="$1" output
    shift
    if output="$("$@" 2> "$fixture_root/rejected.log")"; then
      fail "$label was incorrectly reported successful"
    fi
    [[ -z "$output" ]] || fail "$label returned a successful artifact path on failure: $output"
  }
  check_sidecar() {
    local artifact="$1"
    [[ -s "$artifact" && -s "$artifact.sha256" ]] || fail 'artifact or checksum is missing'
    (cd "$(dirname "$artifact")" && sha256sum --check --status "$(basename "$artifact").sha256") \
      || fail "incorrect transport checksum: $artifact"
  }

  report="$fixture_root/live.tsv"
  {
    printf 'SCHEMA\tfgc-live-preflight\t2\nSTATUS\tCHECK\tDETAIL\n'
    while IFS=$'\t' read -r identifier requirement evidence; do
      if [[ "$requirement" == required ]]; then status=PASS; else status=NOT_TESTED; fi
      printf '%s\t%s\trequirement=%s evidence=%s; captured fixture\n' "$status" "$identifier" "$requirement" "$evidence"
    done < <(live_check_catalog)
    printf 'SUMMARY\tFAIL=0\trequired NOT_TESTED=0\n'
    printf 'DECISION\tGO\tpreinstallation only; installed system NOT_CERTIFIED\n'
  } > "$report"

  validation_require_live_runtime || fail 'native Live runtime was rejected'
  assert_fails 'Live runtime certifying installed services' validation_require_installed_runtime
  proof="$(validation_write_live_proof "$report")" || fail 'Live proof creation failed'
  [[ -s "$proof" && "$(stat -c '%a' "$proof")" == 600 ]] || fail 'proof file or mode is wrong'
  validation_verify_proof "$proof" 2 || fail 'fresh Live proof rejected'
  assert_fails 'obsolete gate 1 verification' validation_verify_proof "$proof" 1
  python3 -B - "$proof" <<'PY_VALIDATE'
import json
import sys
proof=json.load(open(sys.argv[1]))
assert proof['schema']==2 and proof['gate']==2 and proof['environment']=='live-usb'
assert proof['hardware_certification']=='PREINSTALL_ONLY'
assert proof['live_kernel']=='7.1.8-live.fc45.x86_64'
assert len(proof['checks'])==16
assert any(row['status']=='NOT_TESTED' for row in proof['checks'])
assert all(row['status']!='FAIL' for row in proof['checks'])
PY_VALIDATE
  [[ ! -e "$STATE_ROOT/final/certified.ok" ]] || fail 'Live proof creation issued a final certificate'
  if validation_final_certificate_valid; then fail 'Live observations became Golden PASS'; fi
  pipeline="$(validation_pipeline_status)"
  grep -Fxq 'live_usb=PASS' <<< "$pipeline" || fail 'Live proof state was lost'
  grep -Fxq 'gate3_final=PENDING' <<< "$pipeline" || fail 'Live status claims installed certification'

  exported="$(validation_export_proof 2 "$fixture_root/external-support")" || fail 'Live export failed'
  cmp -s "$proof" "$exported" || fail 'export changed the proof bytes'
  check_sidecar "$exported"
  assert_fails 'obsolete gate 1 export' validation_export_proof 1 "$fixture_root/obsolete-export"

  # Same source and physical identities after installation, with a different
  # root filesystem and kernel. Neither is part of the portable Live identity.
  STATE_ROOT="$fixture_root/installed-state"
  FIXTURE_LIVE=false
  FIXTURE_KERNEL='7.3.2-vanilla.fc45.x86_64'
  validation_require_installed_runtime || fail 'installed physical runtime was rejected'
  assert_fails 'installed runtime posing as Live' validation_require_live_runtime
  imported="$(validation_import_proof "$exported")" || fail 'installed import rejected a different running kernel'
  cmp -s "$exported" "$imported" || fail 'import changed the proof bytes'
  check_sidecar "$imported"
  validation_require_imported_gate 2 || fail 'current imported Live proof rejected'
  validation_require_chain || fail 'installed qualification did not find its matching Live proof'
  assert_fails 'obsolete gate 1 import requirement' validation_require_imported_gate 1
  second_export="$(validation_export_proof 2 "$fixture_root/re-export")" || fail 'export did not fall back to the imported Live proof'
  cmp -s "$imported" "$second_export" || fail 're-export changed the proof bytes'
  check_sidecar "$second_export"
  assert_fails 'installed runtime creating Live proof' validation_write_live_proof "$report"

  FIXTURE_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  assert_fails 'different source commit' validation_verify_proof "$imported" 2
  FIXTURE_COMMIT=1111111111111111111111111111111111111111
  printf 'different module plan\n' > "$REPO_ROOT/manifests/module-plan.conf"
  assert_fails 'different module plan' validation_verify_proof "$imported" 2
  cp "$fixture_root/original-plan" "$REPO_ROOT/manifests/module-plan.conf"
  FIXTURE_HARDWARE=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  assert_fails 'different physical hardware' validation_verify_proof "$imported" 2
  FIXTURE_HARDWARE=3333333333333333333333333333333333333333333333333333333333333333
  validation_verify_proof "$imported" 2 || fail 'matching identities were not restored'
  FIXTURE_CLEAN=false
  assert_fails 'dirty current checkout verifying a clean-source record' validation_verify_proof "$imported" 2
  assert_fails 'dirty current checkout importing a clean-source record' validation_import_proof "$exported"
  FIXTURE_CLEAN=true
  validation_verify_proof "$imported" 2 || fail 'restored clean current checkout was rejected'

  before="$(validation_file_sha256 "$imported")"
  for variant in old-schema virtualbox failed-check; do
    forged="$fixture_root/$variant.json"
    python3 -B - "$exported" "$forged" "$variant" <<'PY_FORGE'
import json
import sys
data=json.load(open(sys.argv[1]))
if sys.argv[3]=='old-schema': data['schema']=1
elif sys.argv[3]=='virtualbox': data['environment']='virtualbox'
else: data['checks'][-1]['status']='FAIL'
with open(sys.argv[2], 'w') as handle: json.dump(data,handle)
PY_FORGE
    assert_fails "$variant import" validation_import_proof "$forged"
    [[ "$(validation_file_sha256 "$imported")" == "$before" ]] || fail 'rejected proof overwrote a valid imported record'
  done

  # JSON and checksum failures must remain failures even under $(...) ||/if,
  # where Bash otherwise disables errexit inside the called function.
  STATE_ROOT="$fixture_root/write-error-state"
  FIXTURE_LIVE=true
  FIXTURE_FAIL_WRITE="$(validation_gate_proof_path 2)"
  assert_fails 'proof JSON write failure' validation_write_live_proof "$report"
  [[ ! -e "$FIXTURE_FAIL_WRITE" ]] || fail 'failed writer produced a proof'
  FIXTURE_FAIL_WRITE=''
  FIXTURE_CAT_FAIL=true
  assert_fails 'atomic writer stream failure' validation_write_live_proof "$report"
  FIXTURE_CAT_FAIL=false
  [[ ! -e "$(validation_gate_proof_path 2)" ]] || fail 'failed atomic stream became a published proof'
  FIXTURE_CLEAN=false
  assert_fails 'dirty checkout creating Live proof' validation_write_live_proof "$report"
  FIXTURE_CLEAN=true
  for runtime in wsl2 vm container; do
    RUNTIME_ENVIRONMENT="$runtime"
    assert_fails "non-native $runtime Live creation" validation_write_live_proof "$report"
  done
  RUNTIME_ENVIRONMENT=baremetal
  FIXTURE_LIVE=false
  FIXTURE_FAIL_WRITE="$(validation_imported_proof_path 2)"
  assert_fails 'import JSON write failure' validation_import_proof "$exported"
  FIXTURE_FAIL_WRITE="$(validation_imported_proof_path 2).sha256"
  assert_fails 'import checksum write failure' validation_import_proof "$exported"
  FIXTURE_FAIL_WRITE=''
  imported="$(validation_import_proof "$exported")" || fail 'import failed after restoring the writer'
  check_sidecar "$imported"
  FIXTURE_FAIL_HASH="$(validation_imported_proof_path 2)"
  assert_fails 'import checksum calculation failure' validation_import_proof "$exported"
  FIXTURE_FAIL_HASH=''
  FIXTURE_INSTALL_FAIL=true
  assert_fails 'export JSON install failure' validation_export_proof 2 "$fixture_root/export-json-failure"
  FIXTURE_INSTALL_FAIL=false
  export_dir="$fixture_root/export-checksum-failure"
  mkdir -p "$export_dir/$(basename "$imported").sha256"
  assert_fails 'export checksum write failure' validation_export_proof 2 "$export_dir"
  FIXTURE_FAIL_HASH="$fixture_root/export-hash-failure/$(basename "$imported")"
  assert_fails 'export checksum calculation failure' validation_export_proof 2 "$fixture_root/export-hash-failure"
  FIXTURE_FAIL_HASH=''
  exported_after_error="$(validation_export_proof 2 "$fixture_root/export-recovered")" || fail 'export failed after restoring the target'
  check_sidecar "$exported_after_error"
)


# Exercise the real Live wrapper: a failed new observation must invalidate both
# possible successful-record locations. It must not silently fall back to an
# imported record from a previous run when status/export is requested later.
wrapper_repo="$fixture_root/wrapper-repo"
mkdir -p "$wrapper_repo/lib" "$wrapper_repo/scripts/validation" "$wrapper_repo/diagnostics"
cp "$ROOT/scripts/validation/live-usb.sh" "$wrapper_repo/scripts/validation/live-usb.sh"
cp "$ROOT/lib/validation_gates.sh" "$ROOT/lib/live_preflight_probe.sh" "$wrapper_repo/lib/"
command cat > "$wrapper_repo/lib/bootstrap.sh" <<'BOOTSTRAP'
engine_bootstrap() {
  STATE_ROOT="${FGC_TEST_LIVE_STATE:?}"
  source "${FGC_TEST_REAL_ROOT:?}/lib/constants.sh"
  runtime_is_baremetal() { return 0; }
  runtime_is_live() { return 0; }
  git() { [[ "$*" == "-C $REPO_ROOT status --porcelain" ]]; }
  repo_commit() { printf '1111111111111111111111111111111111111111\n'; }
  ui_error() { printf 'ERROR: %s\n' "$*" >&2; }
}
BOOTSTRAP
command cat > "$wrapper_repo/diagnostics/live-preflight.sh" <<'DIAGNOSTIC'
printf 'STATUS\tCHECK\tDETAIL\nSCHEMA\tfgc-live-preflight\t2\nFAIL\tgpu\tfixture GPU failure\n'
exit 20
DIAGNOSTIC
wrapper_state="$fixture_root/wrapper-state"
old_outbox="$wrapper_state/validation/outbox/live-1111111111111111111111111111111111111111.json"
old_imported="$wrapper_state/validation/imported/live.json"
mkdir -p "$(dirname "$old_outbox")" "$(dirname "$old_imported")"
cp "$fixture_root/external-support/$(basename "$old_outbox")" "$old_outbox"
cp "$old_outbox" "$old_imported"
printf 'previous checksum\n' > "$old_imported.sha256"
if FGC_TEST_LIVE_STATE="$wrapper_state" FGC_TEST_REAL_ROOT="$ROOT" \
    bash "$wrapper_repo/scripts/validation/live-usb.sh" run > "$fixture_root/wrapper-output.log" 2>&1; then
  fail 'failed new Live observations were incorrectly reported successful'
fi
[[ ! -e "$old_outbox" && ! -e "$old_imported" ]] \
  || fail 'failed new Live observations retained a previous successful record'
grep -Fq 'fixture GPU failure' "$wrapper_state/validation/live-preflight.tsv" \
  || fail 'the failed Live report was not retained for diagnosis'


# Live records always describe exact committed sources, even when the separate
# production APPLY policy deliberately disables its clean-Git requirement.
(
  REPO_ROOT="$fixture_root/real-git-repo"
  STATE_ROOT="$fixture_root/real-git-state"
  REQUIRE_CLEAN_GIT=false
  RUNTIME_ENVIRONMENT=baremetal
  mkdir -p "$REPO_ROOT/lib" "$REPO_ROOT/manifests"
  cp "$ROOT/lib/live_validation.py" "$ROOT/lib/live_preflight_probe.sh" "$REPO_ROOT/lib/"
  cp "$fixture_root/original-plan" "$REPO_ROOT/manifests/module-plan.conf"
  printf 'committed source\n' > "$REPO_ROOT/fixture.txt"
  git -C "$REPO_ROOT" init -q
  git -C "$REPO_ROOT" add .
  git -C "$REPO_ROOT" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Live source fixture'
  source "$ROOT/lib/constants.sh"
  source "$ROOT/lib/common.sh"
  source "$ROOT/lib/evidence.sh"
  source "$ROOT/lib/apply_gate.sh"
  source "$ROOT/lib/validation_gates.sh"
  runtime_is_baremetal() { return 0; }
  validation_runtime_is_live() { return 0; }
  validation_hardware_fingerprint() { printf '%s\n' 3333333333333333333333333333333333333333333333333333333333333333; }
  ui_error() { printf 'ERROR: %s\n' "$*" >&2; }
  record="$(validation_write_live_proof "$fixture_root/live.tsv")" || fail 'real clean Git fixture was rejected'
  validation_verify_proof "$record" 2 || fail 'real clean Git proof failed verification'
  printf 'uncommitted change\n' >> "$REPO_ROOT/fixture.txt"
  apply_gate_require_clean_git || fail 'fixture did not disable the separate APPLY clean-Git policy'
  if validation_require_clean_source 2>/dev/null; then fail 'APPLY policy bypassed Live clean-source requirement'; fi
  if validation_verify_proof "$record" 2; then fail 'APPLY policy allowed a dirty source to reuse Live evidence'; fi
  if validation_write_live_proof "$fixture_root/live.tsv" >/dev/null 2>&1; then
    fail 'APPLY policy allowed a dirty source to issue Live evidence'
  fi
  git -C "$REPO_ROOT" checkout -- fixture.txt
  validation_verify_proof "$record" 2 || fail 'restoring exact real Git sources did not restore validity'
  mv "$REPO_ROOT/.git" "$fixture_root/removed-git-metadata"
  if validation_require_clean_source 2>/dev/null; then fail 'missing Git metadata was treated as a clean source'; fi
)

echo 'Native Live proof serialization/import/export and failure propagation: PASS (fixtures only)'
