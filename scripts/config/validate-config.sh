#!/usr/bin/env bash
set -Eeuo pipefail

config_dir="${1:-}"
mode="${2:-validate}"
[[ -n "$config_dir" && -d "$config_dir" ]] || { echo 'Usage: validate-config.sh <config-dir> [validate|--emit-schema]' >&2; exit 2; }
schema_file="$config_dir/schema.digest"
enum_file="$config_dir/schema-enums.tsv"

trim() {
  local v="$*"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

safe_value() {
  local raw="$1"
  [[ "$raw" != *'$('* && "$raw" != *'`'* && "$raw" != *'<('* && "$raw" != *'>('* && "$raw" != *';'* && "$raw" != *'&&'* && "$raw" != *'||'* ]]
}

decode_value() {
  local raw
  raw="$(trim "$1")"
  safe_value "$raw" || return 1
  if [[ "$raw" == \"*\" && "$raw" == *\" ]]; then
    raw="${raw:1:${#raw}-2}"
  elif [[ "$raw" == \'*\' && "$raw" == *\' ]]; then
    raw="${raw:1:${#raw}-2}"
  elif [[ "$raw" =~ [[:space:]] ]]; then
    return 1
  fi
  printf '%s' "$raw"
}

is_ipv4() {
  local value="$1" octet
  local IFS=.
  read -r -a parts <<<"$value"
  ((${#parts[@]} == 4)) || return 1
  for octet in "${parts[@]}"; do
    [[ "$octet" =~ ^[0-9]+$ ]] || return 1
    ((10#$octet >= 0 && 10#$octet <= 255)) || return 1
  done
}

classify_value() {
  local key="$1" value="$2" ip prefix
  case "$key" in
    BACKUP_REPOSITORY) printf 'repository\n'; return 0 ;;
    BACKUP_PASSWORD_FILE|DATA_MOUNT) printf 'optional_path\n'; return 0 ;;
    VAAPI_DRM_DEVICE) printf 'device_or_auto\n'; return 0 ;;
  esac
  case "$value" in true|false) printf 'bool\n'; return 0 ;; esac
  if [[ "$value" =~ ^[0-9a-fA-F]{64}$ ]]; then printf 'sha256\n'; return 0; fi
  if [[ "$value" == https://* ]]; then printf 'https_url\n'; return 0; fi
  if [[ "$value" == */* ]]; then
    ip="${value%/*}"; prefix="${value##*/}"
    if is_ipv4 "$ip" && [[ "$prefix" =~ ^[0-9]+$ ]] && ((10#$prefix <= 32)); then printf 'cidr4\n'; return 0; fi
  fi
  if is_ipv4 "$value" 2>/dev/null; then printf 'ipv4\n'; return 0; fi
  if [[ "$value" =~ ^[0-9]+$ ]]; then printf 'uint\n'; return 0; fi
  if [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then printf 'number\n'; return 0; fi
  if [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9._-]+)?$ ]]; then printf 'version\n'; return 0; fi
  if [[ "$value" == /* || "$value" == '$HOME/'* || "$value" == '${HOME}/'* ]]; then printf 'path\n'; return 0; fi
  printf 'string\n'
}

validate_class_value() {
  local key="$1" expected="$2" value="$3" actual
  case "$expected" in
    repository)
      [[ -z "$value" || "$value" == /* || "$value" =~ ^(sftp:|rest:|rest\+|s3:|b2:|azure:|gs:|rclone:) ]] || return 1
      ;;
    optional_path)
      [[ -z "$value" || "$value" == /* || "$value" == '$HOME/'* || "$value" == '${HOME}/'* ]] || return 1
      ;;
    device_or_auto)
      [[ "$value" == auto || "$value" =~ ^/dev/dri/renderD[0-9]+$ ]] || return 1
      ;;
    *)
      actual="$(classify_value "$key" "$value")"
      [[ "$actual" == "$expected" ]] || return 1
      ;;
  esac
}

schema_digest() {
  local type="$1"
  printf '%s\n' "${type_keys[$type]:-}" | sed '/^$/d' | sort -u | sha256sum | awk '{print $1}'
}

declare -A canonical_type=() canonical_value=() type_keys=() seen=()
declare -a all_keys=()
shopt -s nullglob
for file in "$config_dir"/*.conf; do
  [[ "$(basename "$file")" == local.conf ]] && continue
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((lineno+=1))
    stripped="$(trim "$line")"
    [[ -z "$stripped" || "$stripped" == \#* ]] && continue
    [[ "$stripped" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || { echo "$file:$lineno: only KEY=VALUE assignments are allowed" >&2; exit 60; }
    key="${BASH_REMATCH[1]}"; raw="${BASH_REMATCH[2]}"
    [[ -z "${seen[$key]:-}" ]] || { echo "$file:$lineno: duplicate canonical key: $key" >&2; exit 60; }
    value="$(decode_value "$raw")" || { echo "$file:$lineno: unsafe value syntax for $key" >&2; exit 60; }
    type="$(classify_value "$key" "$value")"
    seen[$key]=1; canonical_type[$key]="$type"; canonical_value[$key]="$value"; all_keys+=("$key")
    type_keys[$type]+="$key"$'\n'
  done < "$file"
done
((${#all_keys[@]} > 0)) || { echo 'No canonical config keys found.' >&2; exit 60; }

emit_schema() {
  printf 'schema_version\t1\n'
  printf 'keyset\t%s\n' "$(printf '%s\n' "${all_keys[@]}" | sort -u | sha256sum | awk '{print $1}')"
  local type
  for type in bool cidr4 device_or_auto https_url ipv4 number optional_path path repository sha256 string uint version; do
    printf '%s\t%s\n' "$type" "$(schema_digest "$type")"
  done
}

if [[ "$mode" == '--emit-schema' || "$mode" == emit ]]; then
  emit_schema
  exit 0
fi
[[ "$mode" == validate ]] || { echo "Unknown mode: $mode" >&2; exit 2; }
[[ -r "$schema_file" ]] || { echo "Missing config schema: $schema_file" >&2; exit 60; }

declare -A expected_digest=()
while IFS=$'\t' read -r name digest extra; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -z "${extra:-}" && "$digest" =~ ^([0-9a-f]{64}|1)$ ]] || { echo "Invalid schema line: $name" >&2; exit 60; }
  expected_digest[$name]="$digest"
done < "$schema_file"
[[ "${expected_digest[schema_version]:-}" == 1 ]] || { echo 'Unsupported config schema version.' >&2; exit 60; }
actual_keyset="$(printf '%s\n' "${all_keys[@]}" | sort -u | sha256sum | awk '{print $1}')"
[[ "${expected_digest[keyset]:-}" == "$actual_keyset" ]] || { echo 'Config keyset differs from schema; update schema deliberately.' >&2; exit 60; }
for type in bool cidr4 device_or_auto https_url ipv4 number optional_path path repository sha256 string uint version; do
  actual="$(schema_digest "$type")"
  [[ "${expected_digest[$type]:-}" == "$actual" ]] || { echo "Config type set differs from schema for: $type" >&2; exit 60; }
done

if [[ -r "$enum_file" ]]; then
  while IFS=$'\t' read -r key allowed extra; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    [[ -n "${canonical_type[$key]:-}" && -n "$allowed" && -z "${extra:-}" ]] || { echo "Invalid enum schema entry for $key" >&2; exit 60; }
    case "|$allowed|" in *"|${canonical_value[$key]}|"*) ;; *) echo "Canonical value for $key is outside enum schema" >&2; exit 60 ;; esac
  done < "$enum_file"
fi

validate_overlay() {
  local file="$1" line stripped key raw value expected lineno=0 allowed
  declare -A local_seen=()
  [[ -r "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((lineno+=1))
    stripped="$(trim "$line")"
    [[ -z "$stripped" || "$stripped" == \#* ]] && continue
    [[ "$stripped" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || { echo "$file:$lineno: only KEY=VALUE assignments are allowed" >&2; return 60; }
    key="${BASH_REMATCH[1]}"; raw="${BASH_REMATCH[2]}"
    [[ -n "${canonical_type[$key]:-}" ]] || { echo "$file:$lineno: unknown config key: $key" >&2; return 60; }
    [[ -z "${local_seen[$key]:-}" ]] || { echo "$file:$lineno: duplicate override key: $key" >&2; return 60; }
    value="$(decode_value "$raw")" || { echo "$file:$lineno: unsafe value syntax for $key" >&2; return 60; }
    expected="${canonical_type[$key]}"
    validate_class_value "$key" "$expected" "$value" || { echo "$file:$lineno: invalid $expected value for $key" >&2; return 60; }
    if [[ -r "$enum_file" ]]; then
      allowed="$(awk -F '\t' -v key="$key" '$1==key {print $2; exit}' "$enum_file")"
      if [[ -n "$allowed" ]]; then
        case "|$allowed|" in *"|$value|"*) ;; *) echo "$file:$lineno: value for $key is outside enum schema" >&2; return 60 ;; esac
      fi
    fi
    local_seen[$key]=1
  done < "$file"
}

validate_overlay "$config_dir/local.conf"
printf 'config schema validation: PASS (%s keys)\n' "${#all_keys[@]}"
