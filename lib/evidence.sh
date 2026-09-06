#!/usr/bin/env bash
# Common immutable-evidence helpers. REPO_ROOT/STATE_ROOT are provided by bootstrap.
# shellcheck disable=SC2153

evidence_atomic_write() {
  local path="$1" mode="${2:-0600}" dir tmp
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.evidence.XXXXXX")" || return 1
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$path"
}

evidence_file_sha256() {
  local file="$1"
  [[ -r "$file" ]] || return 1
  sha256sum "$file" | awk '{print $1}'
}

effective_config_payload() {
  local file rel
  while IFS= read -r file; do
    rel="${file#"$REPO_ROOT"/}"
    printf '%s\t%s\n' "$rel" "$(evidence_file_sha256 "$file")"
  done < <(
    find "$REPO_ROOT/config" -maxdepth 1 -type f \
      \( -name '*.conf' -o -name '*.policy' -o -name 'schema.digest' -o -name 'schema-enums.tsv' \) \
      -print | sort
  )
  file="$REPO_ROOT/manifests/module-plan.conf"
  [[ -r "$file" ]] && printf '%s\t%s\n' 'manifests/module-plan.conf' "$(evidence_file_sha256 "$file")"
}

effective_config_sha256() {
  effective_config_payload | sha256sum | awk '{print $1}'
}

module_plan_sha256() {
  evidence_file_sha256 "$REPO_ROOT/manifests/module-plan.conf"
}

evidence_hardware_fingerprint() {
  if declare -F runtime_is_baremetal >/dev/null && runtime_is_baremetal && declare -F baseline_fingerprint >/dev/null; then
    baseline_fingerprint
  else
    printf 'deferred:%s\n' "${RUNTIME_ENVIRONMENT:-unknown}"
  fi
}

evidence_marker_value() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

evidence_require_current_identity() {
  local marker="$1" commit config_hash plan_hash hardware
  [[ -s "$marker" ]] || return 1
  commit="$(evidence_marker_value "$marker" commit 2>/dev/null || true)"
  config_hash="$(evidence_marker_value "$marker" effective_config_sha256 2>/dev/null || true)"
  plan_hash="$(evidence_marker_value "$marker" module_plan_sha256 2>/dev/null || true)"
  hardware="$(evidence_marker_value "$marker" hardware_fingerprint 2>/dev/null || true)"
  [[ "$commit" == "$(repo_commit)" ]] || return 1
  [[ "$config_hash" == "$(effective_config_sha256)" ]] || return 1
  [[ "$plan_hash" == "$(module_plan_sha256)" ]] || return 1
  if runtime_is_baremetal; then
    [[ "$hardware" == "$(baseline_fingerprint)" ]] || return 1
  fi
}
