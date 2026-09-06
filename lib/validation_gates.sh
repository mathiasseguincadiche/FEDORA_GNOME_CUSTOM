#!/usr/bin/env bash
# Three-gate validation evidence helpers.
# REPO_ROOT, STATE_ROOT, RUNTIME_ENVIRONMENT and evidence helpers are provided by bootstrap.
# shellcheck disable=SC2153

validation_root() { printf '%s/validation\n' "$STATE_ROOT"; }
validation_outbox_dir() { printf '%s/outbox\n' "$(validation_root)"; }
validation_import_dir() { printf '%s/imported\n' "$(validation_root)"; }
validation_gate_proof_path() { printf '%s/gate%s-%s.json\n' "$(validation_outbox_dir)" "$1" "$(repo_commit)"; }
validation_imported_proof_path() { printf '%s/gate%s.json\n' "$(validation_import_dir)" "$1"; }

validation_gate_label() {
  case "$1" in
    1) printf 'GATE 1 — WSL2 SYSTEM/LOGIC\n' ;;
    2) printf 'GATE 2 — VIRTUALBOX DESKTOP\n' ;;
    3) printf 'GATE 3 — BARE-METAL GOLDEN\n' ;;
    *) return 1 ;;
  esac
}

validation_expected_environment() {
  case "$1" in
    1) printf 'wsl2\n' ;;
    2) printf 'virtualbox\n' ;;
    3) printf 'baremetal\n' ;;
    *) return 1 ;;
  esac
}

validation_fedora_release() {
  [[ -r /etc/os-release ]] || return 1
  awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release
}

validation_require_fedora44() {
  [[ -r /etc/os-release ]] || return "$EXIT_PRECHECK_FAILED"
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || return "$EXIT_PRECHECK_FAILED"
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || return "$EXIT_PRECHECK_FAILED"
}

validation_require_clean_source() {
  apply_gate_require_clean_git || {
    ui_error 'Validation gate requires a clean Git worktree so the portable proof maps to one reviewed source tree'
    return "$EXIT_SECURITY_BLOCK"
  }
}

validation_environment_fingerprint() {
  {
    printf 'runtime=%s\n' "$(runtime_environment)"
    printf 'kernel=%s\n' "$(uname -r 2>/dev/null || printf unknown)"
    printf 'fedora=%s\n' "$(validation_fedora_release 2>/dev/null || printf unknown)"
    if runtime_is_vm; then
      printf 'vm_vendor=%s\n' "$(runtime_vm_vendor_detect 2>/dev/null || printf unknown)"
    fi
    if [[ -r /sys/class/dmi/id/product_name ]]; then
      printf 'product=%s\n' "$(tr -d '\n' < /sys/class/dmi/id/product_name)"
    fi
  } | sha256sum | awk '{print $1}'
}

validation_file_sha256() {
  local file="$1"
  [[ -r "$file" ]] || return 1
  sha256sum "$file" | awk '{print $1}'
}

validation_write_proof() {
  local gate="$1" environment="$2" predecessor_sha256="${3:-}" manual_visual="${4:-N/A}" checks_summary="${5:-PASS}"
  local path expected_environment
  case "$gate" in 1|2) ;; *) return "$EXIT_USAGE" ;; esac
  expected_environment="$(validation_expected_environment "$gate")" || return "$EXIT_USAGE"
  [[ "$environment" == "$expected_environment" ]] || return "$EXIT_CONFIG_FAILED"
  if [[ "$gate" == 1 ]]; then
    [[ -z "$predecessor_sha256" && "$manual_visual" == 'N/A' ]] || return "$EXIT_CONFIG_FAILED"
  else
    [[ "$predecessor_sha256" =~ ^[0-9a-f]{64}$ && "$manual_visual" == 'PASS' ]] || return "$EXIT_CONFIG_FAILED"
  fi
  path="$(validation_gate_proof_path "$gate")"
  mkdir -p "$(dirname "$path")"
  python3 - "$gate" "$environment" "$(repo_commit)" "$(module_plan_sha256)" "$(effective_config_sha256)" \
    "$(validation_environment_fingerprint)" "$predecessor_sha256" "$manual_visual" "$checks_summary" "$(date -u +%FT%TZ)" <<'PY' \
    | evidence_atomic_write "$path" 0600
import json
import sys

gate, environment, commit, module_plan, effective_config, environment_fingerprint, predecessor, manual_visual, checks, created_utc = sys.argv[1:]
payload = {
    "schema": 1,
    "gate": int(gate),
    "verdict": "PASS",
    "environment": environment,
    "project_commit": commit,
    "module_plan_sha256": module_plan,
    "environment_effective_config_sha256": effective_config,
    "environment_fingerprint_sha256": environment_fingerprint,
    "source_tree_clean": True,
    "hardware_certification": "DEFERRED",
    "manual_visual": manual_visual,
    "checks": checks,
    "predecessor_sha256": predecessor or None,
    "created_utc": created_utc,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
  python3 -m json.tool "$path" >/dev/null
  printf '%s\n' "$path"
}

validation_proof_gate() {
  local file="$1"
  python3 - "$file" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("gate", ""))
PY
}

validation_proof_field() {
  local file="$1" field="$2"
  python3 - "$file" "$field" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle).get(sys.argv[2])
if value is None:
    raise SystemExit(1)
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

validation_verify_proof() {
  local file="$1" expected_gate="$2" expected_environment
  [[ -s "$file" ]] || return 1
  expected_environment="$(validation_expected_environment "$expected_gate")" || return 1
  python3 - "$file" "$expected_gate" "$expected_environment" "$(repo_commit)" "$(module_plan_sha256)" <<'PY'
import json
import re
import sys

path, expected_gate, expected_environment, commit, module_plan = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)

required = {
    "schema", "gate", "verdict", "environment", "project_commit",
    "module_plan_sha256", "environment_effective_config_sha256",
    "environment_fingerprint_sha256", "source_tree_clean",
    "hardware_certification", "manual_visual", "checks",
    "predecessor_sha256", "created_utc",
}
if set(data) != required:
    raise SystemExit(1)
if data["schema"] != 1 or data["gate"] != int(expected_gate):
    raise SystemExit(1)
if data["verdict"] != "PASS" or data["environment"] != expected_environment:
    raise SystemExit(1)
if data["project_commit"] != commit or data["module_plan_sha256"] != module_plan:
    raise SystemExit(1)
if data["source_tree_clean"] is not True or data["hardware_certification"] != "DEFERRED":
    raise SystemExit(1)
if not re.fullmatch(r"[0-9a-f]{64}", data["environment_effective_config_sha256"]):
    raise SystemExit(1)
if not re.fullmatch(r"[0-9a-f]{64}", data["environment_fingerprint_sha256"]):
    raise SystemExit(1)
if expected_gate == "1":
    if data.get("manual_visual") != "N/A" or data.get("predecessor_sha256") is not None:
        raise SystemExit(1)
else:
    if data.get("manual_visual") != "PASS":
        raise SystemExit(1)
    if not re.fullmatch(r"[0-9a-f]{64}", data.get("predecessor_sha256") or ""):
        raise SystemExit(1)
PY
}

validation_require_imported_gate() {
  local gate="$1" proof
  proof="$(validation_imported_proof_path "$gate")"
  validation_verify_proof "$proof" "$gate"
}

validation_import_proof() {
  local source="$1" gate destination predecessor imported_gate1 expected_predecessor
  [[ -s "$source" ]] || { ui_error "Validation proof missing: $source"; return "$EXIT_PRECHECK_FAILED"; }
  gate="$(validation_proof_gate "$source" 2>/dev/null || true)"
  case "$gate" in 1|2) ;; *) ui_error 'Only Gate 1 or Gate 2 portable proofs can be imported'; return "$EXIT_CONFIG_FAILED" ;; esac
  validation_verify_proof "$source" "$gate" || {
    ui_error "Gate $gate proof is invalid, stale, or belongs to another commit/module plan"
    return "$EXIT_SECURITY_BLOCK"
  }

  if [[ "$gate" == 2 ]]; then
    imported_gate1="$(validation_imported_proof_path 1)"
    validation_verify_proof "$imported_gate1" 1 || {
      ui_error 'Import the matching Gate 1 proof before Gate 2'
      return "$EXIT_PRECHECK_FAILED"
    }
    predecessor="$(validation_proof_field "$source" predecessor_sha256 2>/dev/null || true)"
    expected_predecessor="$(validation_file_sha256 "$imported_gate1")"
    [[ "$predecessor" == "$expected_predecessor" ]] || {
      ui_error 'Gate 2 proof does not reference the currently imported Gate 1 proof'
      return "$EXIT_SECURITY_BLOCK"
    }
  fi

  destination="$(validation_imported_proof_path "$gate")"
  mkdir -p "$(dirname "$destination")"
  evidence_atomic_write "$destination" 0600 < "$source"
  printf '%s  %s\n' "$(validation_file_sha256 "$destination")" "$(basename "$destination")" \
    | evidence_atomic_write "$destination.sha256" 0600
  printf '%s\n' "$destination"
}

validation_require_chain() {
  local gate1 gate2 expected predecessor
  gate1="$(validation_imported_proof_path 1)"
  gate2="$(validation_imported_proof_path 2)"
  validation_verify_proof "$gate1" 1 || return 1
  validation_verify_proof "$gate2" 2 || return 1
  expected="$(validation_file_sha256 "$gate1")"
  predecessor="$(validation_proof_field "$gate2" predecessor_sha256 2>/dev/null || true)"
  [[ "$predecessor" == "$expected" ]]
}

validation_export_proof() {
  local gate="$1" destination_dir="$2" source destination
  case "$gate" in 1|2) ;; *) return "$EXIT_USAGE" ;; esac
  source="$(validation_gate_proof_path "$gate")"
  if ! validation_verify_proof "$source" "$gate"; then
    source="$(validation_imported_proof_path "$gate")"
    validation_verify_proof "$source" "$gate" || return "$EXIT_PRECHECK_FAILED"
  fi
  mkdir -p "$destination_dir"
  destination="$destination_dir/$(basename "$source")"
  install -m 0600 "$source" "$destination"
  printf '%s  %s\n' "$(validation_file_sha256 "$destination")" "$(basename "$destination")" > "$destination.sha256"
  printf '%s\n' "$destination"
}

validation_gate_state() {
  local gate="$1" proof
  proof="$(validation_imported_proof_path "$gate")"
  if validation_verify_proof "$proof" "$gate"; then
    printf 'PASS\n'
  else
    printf 'PENDING\n'
  fi
}

validation_pipeline_status() {
  local gate1 gate2 chain='PENDING' final='PENDING' cert gate1_hash gate2_hash
  gate1="$(validation_gate_state 1)"
  gate2="$(validation_gate_state 2)"
  if validation_require_chain; then chain='PASS'; fi
  cert="$STATE_ROOT/final/certified.ok"
  if [[ "$chain" == PASS && -s "$cert" ]]; then
    gate1_hash="$(validation_file_sha256 "$(validation_imported_proof_path 1)")"
    gate2_hash="$(validation_file_sha256 "$(validation_imported_proof_path 2)")"
    if grep -Fxq 'verdict=PASS' "$cert" \
      && grep -Fxq 'validation_chain=PASS' "$cert" \
      && grep -Fxq "gate1_proof_sha256=$gate1_hash" "$cert" \
      && grep -Fxq "gate2_proof_sha256=$gate2_hash" "$cert"; then
      final='PASS'
    fi
  fi
  printf 'runtime=%s\n' "$(runtime_environment)"
  printf 'project_commit=%s\n' "$(repo_commit)"
  printf 'gate1=%s\n' "$gate1"
  printf 'gate2=%s\n' "$gate2"
  printf 'chain=%s\n' "$chain"
  printf 'gate3_final=%s\n' "$final"
}
