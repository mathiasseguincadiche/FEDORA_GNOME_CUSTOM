#!/usr/bin/env bash
# Native Live USB observations followed by installed-system qualification.
# shellcheck disable=SC2153
source "$REPO_ROOT/lib/live_preflight_probe.sh"

validation_root() { printf '%s/validation\n' "$STATE_ROOT"; }
validation_outbox_dir() { printf '%s/outbox\n' "$(validation_root)"; }
validation_import_dir() { printf '%s/imported\n' "$(validation_root)"; }
validation_gate_proof_path() { [[ "$1" == 2 ]] || return 1; printf '%s/live-%s.json\n' "$(validation_outbox_dir)" "$(repo_commit)"; }
validation_imported_proof_path() { [[ "$1" == 2 ]] || return 1; printf '%s/live.json\n' "$(validation_import_dir)"; }
validation_gate_label() { case "$1" in 1) printf 'CI — SOFTWARE CHECKS\n';; 2) printf 'LIVE USB — PRE-INSTALL CHECKS\n';; 3) printf 'INSTALLED FEDORA — FINAL QUALIFICATION\n';; *) return 1;; esac; }
validation_expected_environment() { case "$1" in 2) printf 'live-usb\n';; 3) printf 'baremetal\n';; *) return 1;; esac; }
validation_fedora_release() { awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release; }
validation_require_selected_fedora() {
  [[ -r /etc/os-release ]] || return "$EXIT_PRECHECK_FAILED"
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || return "$EXIT_PRECHECK_FAILED"
  fedora_require_selected || return "$EXIT_PRECHECK_FAILED"
}
validation_runtime_is_live() { runtime_is_live; }
validation_require_installed_runtime() {
  if ! runtime_is_baremetal || validation_runtime_is_live; then
    ui_error 'This action requires installed Fedora on the physical PC; a Live session cannot certify installed services'
    return "$EXIT_SECURITY_BLOCK"
  fi
}
validation_require_live_runtime() {
  if ! runtime_is_baremetal || ! validation_runtime_is_live; then
    ui_error 'Live qualification requires a native Live USB session on the physical PC'
    return "$EXIT_SECURITY_BLOCK"
  fi
}
validation_source_is_clean() {
  local status
  status="$(git -C "$REPO_ROOT" status --porcelain)" || return 1
  [[ -z "$status" ]]
}
validation_require_clean_source() {
  validation_source_is_clean || { ui_error 'Use a clean Git checkout for portable Live evidence'; return "$EXIT_SECURITY_BLOCK"; }
}
validation_file_sha256() { [[ -r "$1" ]] || return 1; sha256sum "$1" | awk '{print $1}'; }
validation_hardware_fingerprint() { python3 "$REPO_ROOT/lib/live_validation.py" hardware; }
validation_write_live_proof() {
  local report="$1" path temporary hardware
  validation_require_live_runtime || return $?
  validation_require_clean_source || return $?
  hardware="$(validation_hardware_fingerprint)" || return "$EXIT_PRECHECK_FAILED"
  path="$(validation_gate_proof_path 2)"
  mkdir -p "$(dirname "$path")"
  temporary="$(mktemp)"
  if ! python3 "$REPO_ROOT/lib/live_validation.py" create --file "$report" --catalog "$(live_check_catalog)" \
      --commit "$(repo_commit)" --module-plan "$(module_plan_sha256)" --hardware "$hardware" --kernel "$(uname -r)" > "$temporary"; then
    rm -f "$temporary"; return "$EXIT_PRECHECK_FAILED"
  fi
  evidence_atomic_write "$path" 0600 < "$temporary" || { rm -f "$temporary"; return "$EXIT_PRECHECK_FAILED"; }
  rm -f "$temporary"
  printf '%s\n' "$path"
}
validation_proof_gate() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("gate", ""))' "$1"; }
validation_proof_field() {
  python3 - "$1" "$2" <<'PY_FIELD'
import json,sys
value=json.load(open(sys.argv[1])).get(sys.argv[2])
if value is None: raise SystemExit(1)
print(str(value).lower() if isinstance(value,bool) else value)
PY_FIELD
}
validation_verify_proof() {
  local file="$1" expected_gate="$2" hardware
  [[ "$expected_gate" == 2 && -s "$file" ]] || return 1
  validation_source_is_clean || return 1
  hardware="$(validation_hardware_fingerprint)" || return 1
  python3 "$REPO_ROOT/lib/live_validation.py" verify --file "$file" --catalog "$(live_check_catalog)" \
    --commit "$(repo_commit)" --module-plan "$(module_plan_sha256)" --hardware "$hardware"
}
validation_require_imported_gate() { [[ "$1" == 2 ]] || return 1; validation_verify_proof "$(validation_imported_proof_path 2)" 2; }
validation_import_proof() {
  local source="$1" destination checksum
  [[ -s "$source" ]] || { ui_error "Live proof missing: $source"; return "$EXIT_PRECHECK_FAILED"; }
  validation_verify_proof "$source" 2 || { ui_error 'Live proof is incomplete, stale or belongs to another source/hardware'; return "$EXIT_SECURITY_BLOCK"; }
  destination="$(validation_imported_proof_path 2)"
  mkdir -p "$(dirname "$destination")"
  evidence_atomic_write "$destination" 0600 < "$source" || return "$EXIT_PRECHECK_FAILED"
  checksum="$(validation_file_sha256 "$destination")" || return "$EXIT_PRECHECK_FAILED"
  printf '%s  %s\n' "$checksum" "$(basename "$destination")" | evidence_atomic_write "$destination.sha256" 0600 || return "$EXIT_PRECHECK_FAILED"
  printf '%s\n' "$destination"
}
# Kept as a common internal predicate: Live observations -> installed qualification.
validation_require_chain() { validation_require_imported_gate 2; }

validation_suspend_evidence_valid() {
  local file="$1" field expected
  [[ -s "$file" ]] || return 1
  for field in fingerprint effective_config_sha256 live_proof_sha256 display_edid_sha256 driver_contract; do
    case "$field" in
      fingerprint) expected="$(workstation_runtime_fingerprint)" ;;
      effective_config_sha256) expected="$(effective_config_sha256)" ;;
      live_proof_sha256) expected="$(validation_file_sha256 "$(validation_imported_proof_path 2)")" || return 1 ;;
      display_edid_sha256) expected="$(hardware_b580_expected_edid_sha256)" || return 1 ;;
      driver_contract) expected=PASS ;;
    esac
    grep -Fxq "$field=$expected" "$file" || return 1
  done
  [[ "$(evidence_marker_value "$file" cycle_id)" =~ ^[0-9a-f]{64}$ ]]
}

validation_export_proof() {
  local gate="$1" destination_dir="$2" source destination checksum
  case "$gate" in 2) ;; *) return "$EXIT_USAGE" ;; esac
  source="$(validation_gate_proof_path "$gate")"
  if ! validation_verify_proof "$source" "$gate"; then
    source="$(validation_imported_proof_path "$gate")"
    validation_verify_proof "$source" "$gate" || return "$EXIT_PRECHECK_FAILED"
  fi
  mkdir -p "$destination_dir"
  destination="$destination_dir/$(basename "$source")"
  install -m 0600 "$source" "$destination" || return "$EXIT_PRECHECK_FAILED"
  checksum="$(validation_file_sha256 "$destination")" || return "$EXIT_PRECHECK_FAILED"
  printf '%s  %s\n' "$checksum" "$(basename "$destination")" > "$destination.sha256" || return "$EXIT_PRECHECK_FAILED"
  printf '%s\n' "$destination"
}

validation_gate_state() {
  local gate="$1" proof
  proof="$(validation_imported_proof_path "$gate")"
  if validation_verify_proof "$proof" "$gate" || validation_verify_proof "$(validation_gate_proof_path "$gate")" "$gate"; then
    printf 'PASS\n'
  else
    printf 'PENDING\n'
  fi
}

# Read-only certificate identity check shared by the dashboard and doctor.
# This checks recorded evidence; certify is responsible for live exercises.
validation_final_certificate_valid() {
  local cert="$STATE_ROOT/final/certified.ok" contract
  runtime_is_baremetal && ! validation_runtime_is_live || return 1
  validation_require_chain || return 1
  [[ -s "$cert" ]] || return 1
  for contract in verdict validation_chain driver_contract application_runtime_contract backup_runtime_contract physical_runtime_contract performance_contract gaming_contract; do
    grep -Fxq "$contract=PASS" "$cert" || return 1
  done
  grep -Fxq 'gaming_profile=true' "$cert" || return 1
  grep -Fxq "fingerprint=$(workstation_runtime_fingerprint)" "$cert" || return 1
  grep -Fxq "hardware_fingerprint=$(baseline_fingerprint)" "$cert" || return 1
  grep -Fxq "effective_config_sha256=$(effective_config_sha256)" "$cert" || return 1
  grep -Fxq "module_plan_sha256=$(module_plan_sha256)" "$cert" || return 1
  grep -Fxq "live_proof_sha256=$(validation_file_sha256 "$(validation_imported_proof_path 2)")" "$cert" || return 1
  if is_true "${ENABLE_KVM:-true}"; then
    for contract in kvm_domain_contract kvm_runtime_contract; do
      grep -Fxq "$contract=PASS" "$cert" || return 1
    done
  fi
}

validation_pipeline_status() {
  local live final='PENDING'
  live="$(validation_gate_state 2)"
  if validation_final_certificate_valid; then final=PASS; fi
  printf 'runtime=%s\nproject_commit=%s\nlive_usb=%s\ngate3_final=%s\n' "$(runtime_environment)" "$(repo_commit)" "$live" "$final"
}
