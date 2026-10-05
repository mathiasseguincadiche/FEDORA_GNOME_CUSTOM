#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
prefix="${1:-}"
case "$prefix" in DING|SHOW_DESKTOP_PLUS|RESOURCE_MONITOR|TILING_ASSISTANT) ;; *) exit 2 ;; esac
shift
release="${HOST_RELEASE:-44}"
# The child installer must select the same lock as the parent engine.
if [[ -r "$root/config/local.conf" ]]; then
  bash "$root/scripts/config/validate-config.sh" "$root/config" >/dev/null
  configured="$(awk -F= '$1 ~ /^[[:space:]]*HOST_RELEASE$/ {gsub(/"/,"",$2); print $2}' "$root/config/local.conf")"
  [[ -z "$configured" ]] || release="$configured"
fi
case "$release" in
  44) source "$root/config/gnome-extensions.lock" ;;
  45)
    python3 "$root/scripts/development/fedora-profile.py" validate "$root" 45
    source "$root/profiles/fedora45/gnome-extensions.lock"
    ;;
  *) echo 'Unsupported Fedora release' >&2; exit 2 ;;
esac
url_key="${prefix}_SOURCE_URL"; uuid_key="${prefix}_UUID"
shell_key="${prefix}_SHELL_VERSION"; sha_key="${prefix}_SHA256"
version_key="${prefix}_VERSION"; review_key="${prefix}_REVIEW_ID"; schema_key="${prefix}_SCHEMA"
url="${1:-${!url_key}}"; uuid="${2:-${!uuid_key}}"; shell_version="${3:-${!shell_key}}"
[[ $# -le 3 && "$url" == "${!url_key}" && "$uuid" == "${!uuid_key}" && "$shell_version" == "${!shell_key}" ]] || {
  echo "Extension arguments do not match the reviewed lock: $prefix" >&2; exit 2
}
expected_sha256="${!sha_key}"
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || exit 2
for cmd in curl unzip python3 sha256sum gnome-extensions glib-compile-schemas; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
zip="$work/extension.zip"; metadata="$work/metadata.json"
cache="${FGC_EXTENSION_ARTIFACT_CACHE:-}"
if [[ -n "$cache" ]]; then
  [[ "$cache" == /* && -r "$cache/$prefix.zip" ]] || { echo 'Reviewed artifact cache is missing or not absolute' >&2; exit 1; }
  cp -- "$cache/$prefix.zip" "$zip"
else
curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$zip"
fi
printf '%s  %s\n' "$expected_sha256" "$zip" | sha256sum --check --status || { echo 'Extension SHA-256 mismatch' >&2; exit 1; }
unzip -p "$zip" metadata.json > "$metadata"
python3 "$root/scripts/gnome/validate-extension-metadata.py" "$metadata" "$uuid" "$shell_version"
gnome-extensions install --force "$zip"
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
schema_dir="$extension_dir/schemas"
python3 "$root/scripts/gnome/validate-extension-metadata.py" "$extension_dir/metadata.json" "$uuid" "$shell_version"
[[ -d "$schema_dir" ]] || { echo 'Installed extension schemas missing' >&2; exit 1; }
if [[ -n "${!schema_key:-}" ]]; then
  [[ -r "$schema_dir/${!schema_key}.gschema.xml" ]] || exit 1
fi
glib-compile-schemas "$schema_dir"
{
  printf 'source_url=%s\nshell_version=%s\nsha256=%s\n' "$url" "$shell_version" "$expected_sha256"
  if [[ -n "${!review_key:-}" ]]; then
    printf 'review_id=%s\nsite_version=%s\n' "${!review_key}" "${!version_key}"
  else
    printf 'release=v%s\n' "${!version_key}"
  fi
} > "$extension_dir/.fedora-gnome-custom-source"
printf 'Installed reviewed extension: %s\n' "$uuid"
