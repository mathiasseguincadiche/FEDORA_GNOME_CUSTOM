#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

usage() {
  cat <<'EOF'
Usage:
  archive-golden-payloads.sh --destination DIR --payload PATH [--payload PATH ...]

Copies explicitly supplied installation payloads into an external archive,
binds them to the current certified Golden release metadata, and writes
SHA-256 manifests. It never downloads payloads and never writes them into Git.
EOF
}

destination=''
declare -a payloads=()
while (($#)); do
  case "$1" in
    --destination)
      [[ $# -ge 2 ]] || { usage >&2; exit "$EXIT_USAGE"; }
      destination="$2"; shift 2 ;;
    --payload)
      [[ $# -ge 2 ]] || { usage >&2; exit "$EXIT_USAGE"; }
      payloads+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit "$EXIT_USAGE" ;;
  esac
done

[[ -n "$destination" && ${#payloads[@]} -gt 0 ]] || { usage >&2; exit "$EXIT_USAGE"; }
[[ -s "$STATE_ROOT/final/certified.ok" ]] || { ui_error 'Golden certification marker is required before payload archival'; exit "$EXIT_PRECHECK_FAILED"; }
grep -Fxq 'verdict=PASS' "$STATE_ROOT/final/certified.ok" || { ui_error 'Current Golden certification is not PASS'; exit "$EXIT_PRECHECK_FAILED"; }

release_manifest="$(awk -F= '$1=="golden_release_manifest" {sub(/^[^=]*=/,""); print; exit}' "$STATE_ROOT/final/certified.ok")"
[[ -n "$release_manifest" && -s "$release_manifest" ]] || { ui_error 'Golden release manifest referenced by certification is missing'; exit "$EXIT_PRECHECK_FAILED"; }
release_dir="$(dirname "$release_manifest")"

mkdir -p "$destination"
destination="$(realpath "$destination")"
repo_real="$(realpath "$REPO_ROOT")"
[[ "$destination" != "$repo_real" && "$destination" != "$repo_real"/* ]] || { ui_error 'Payload archive must live outside the Git checkout'; exit "$EXIT_SECURITY_BLOCK"; }

archive_root="$destination/golden-payloads-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$archive_root/metadata" "$archive_root/payloads"
cp -a "$release_dir/." "$archive_root/metadata/"

for source in "${payloads[@]}"; do
  [[ -e "$source" ]] || { ui_error "Payload does not exist: $source"; exit "$EXIT_PRECHECK_FAILED"; }
  source="$(realpath "$source")"
  name="$(basename "$source")"
  [[ ! -e "$archive_root/payloads/$name" ]] || { ui_error "Payload basename collision: $name"; exit "$EXIT_CONFIG_FAILED"; }
  cp -a --reflink=auto "$source" "$archive_root/payloads/$name"
done

(
  cd "$archive_root"
  find payloads -type f -print0 | sort -z | xargs -0 -r sha256sum > PAYLOADS.sha256
  find metadata -type f -print0 | sort -z | xargs -0 -r sha256sum > METADATA.sha256
)

cat > "$archive_root/ARCHIVE_INFO.txt" <<EOF
FEDORA_GNOME_CUSTOM Golden payload archive
utc=$(date -u +%FT%TZ)
commit=$(repo_commit)
effective_config_sha256=$(effective_config_sha256)
golden_release_manifest=$release_manifest
payload_count=${#payloads[@]}

This archive contains only payloads explicitly supplied by the operator.
PAYLOADS.sha256 covers archived installation payloads.
METADATA.sha256 covers the copied Golden release metadata.
EOF

ui_check OK 'Golden payload archive' "$archive_root"
ui_meta 'Payload count' "${#payloads[@]}"
ui_meta 'Payload manifest' "$archive_root/PAYLOADS.sha256"
