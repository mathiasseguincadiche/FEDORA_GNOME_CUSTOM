#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

usage() {
  cat <<'EOF'
Usage: seal-golden-archive.sh DESTINATION PAYLOAD [PAYLOAD ...]

Create an integrity-sealed, off-repository archive containing the currently
certified Golden release bundle plus one or more operator-supplied payloads.

Recommended payloads include the certified Fedora ISO/CHECKSUM/keyring,
offline RPM or Flatpak mirrors/caches, and Windows/VirtIO installation media.
The script never downloads external payloads automatically.
EOF
}

(($# >= 2)) || { usage >&2; exit "$EXIT_USAGE"; }
runtime_is_baremetal || { echo 'Golden payload archival requires the certified bare-metal workstation' >&2; exit "$EXIT_SECURITY_BLOCK"; }

destination="$1"
shift
payloads=("$@")

cert="$STATE_ROOT/final/certified.ok"
[[ -s "$cert" ]] || { echo 'No final Golden certification marker is present' >&2; exit "$EXIT_PRECHECK_FAILED"; }
grep -Fxq 'verdict=PASS' "$cert" || { echo 'Final certification marker is not PASS' >&2; exit "$EXIT_PRECHECK_FAILED"; }
grep -Fxq "fingerprint=$(workstation_runtime_fingerprint)" "$cert" || { echo 'Final certification is stale for the current runtime fingerprint' >&2; exit "$EXIT_PRECHECK_FAILED"; }
grep -Fxq "effective_config_sha256=$(effective_config_sha256)" "$cert" || { echo 'Final certification is stale for the current effective configuration' >&2; exit "$EXIT_PRECHECK_FAILED"; }

release_manifest="$(awk -F= '$1=="golden_release_manifest" {sub(/^[^=]*=/, ""); print; exit}' "$cert")"
[[ -n "$release_manifest" ]] || { echo 'Certified marker has no Golden release manifest path' >&2; exit "$EXIT_PRECHECK_FAILED"; }
if [[ "$release_manifest" != /* ]]; then release_manifest="$REPO_ROOT/$release_manifest"; fi
[[ -s "$release_manifest" ]] || { echo "Golden release manifest is missing: $release_manifest" >&2; exit "$EXIT_PRECHECK_FAILED"; }

release_dir="$(dirname "$release_manifest")"
release_dir_abs="$(realpath -m "$release_dir")"
releases_root_abs="$(realpath -m "$STATE_ROOT/releases")"
case "$release_dir_abs" in
  "$releases_root_abs"/*) ;;
  *) echo 'Certified Golden release must live under state/releases/' >&2; exit "$EXIT_SECURITY_BLOCK" ;;
esac

[[ -s "$release_dir/MANIFEST.sha256" ]] || { echo 'Golden release MANIFEST.sha256 is missing' >&2; exit "$EXIT_PRECHECK_FAILED"; }
(
  cd "$release_dir"
  sha256sum -c MANIFEST.sha256 >/dev/null
) || { echo 'Golden release bundle integrity verification failed' >&2; exit "$EXIT_POSTCHECK_FAILED"; }

repo_abs="$(realpath -m "$REPO_ROOT")"
dest_abs="$(realpath -m "$destination")"
case "$dest_abs" in
  "$repo_abs"|"$repo_abs"/*)
    echo 'Golden payload archives must be stored outside the Git checkout' >&2
    exit "$EXIT_SECURITY_BLOCK"
    ;;
esac

declare -A payload_names=()
for payload in "${payloads[@]}"; do
  [[ -e "$payload" ]] || { echo "Payload does not exist: $payload" >&2; exit "$EXIT_PRECHECK_FAILED"; }
  payload_abs="$(realpath "$payload")"
  case "$dest_abs" in
    "$payload_abs"|"$payload_abs"/*)
      echo "Destination must not be inside a payload source: $payload_abs" >&2
      exit "$EXIT_SECURITY_BLOCK"
      ;;
  esac
  base="$(basename "$payload")"
  [[ -z "${payload_names[$base]+x}" ]] || { echo "Payload basename collision: $base" >&2; exit "$EXIT_SECURITY_BLOCK"; }
  payload_names["$base"]=1
done

if [[ -e "$dest_abs" ]]; then
  [[ -d "$dest_abs" && -z "$(find "$dest_abs" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
    echo "Destination must be absent or empty: $dest_abs" >&2
    exit "$EXIT_SECURITY_BLOCK"
  }
else
  mkdir -p "$dest_abs"
fi

mkdir -p "$dest_abs/release" "$dest_abs/payloads"
cp -a "$release_dir/." "$dest_abs/release/"

for payload in "${payloads[@]}"; do
  base="$(basename "$payload")"
  cp -a -- "$payload" "$dest_abs/payloads/$base"
done

cat > "$dest_abs/ARCHIVE.txt" <<EOF
schema=1
created_utc=$(date -u +%FT%TZ)
project_commit=$(repo_commit)
effective_config_sha256=$(effective_config_sha256)
golden_release_manifest=$(basename "$release_manifest")
golden_release_manifest_sha256=$(sha256sum "$release_manifest" | awk '{print $1}')
payload_count=${#payloads[@]}
policy=operator-supplied-offline-payloads
EOF

manifest_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp"' EXIT
(
  cd "$dest_abs"
  find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > "$manifest_tmp"
  mv -f "$manifest_tmp" MANIFEST.sha256
  sha256sum -c MANIFEST.sha256 >/dev/null
)
trap - EXIT

printf 'Golden archive sealed: %s\n' "$dest_abs"
printf 'Payloads included: %d\n' "${#payloads[@]}"
printf 'Verify later with: (cd %q && sha256sum -c MANIFEST.sha256)\n' "$dest_abs"
