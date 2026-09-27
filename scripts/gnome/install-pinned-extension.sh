#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
prefix="${1:-}"
case "$prefix" in DING|SHOW_DESKTOP_PLUS|RESOURCE_MONITOR|TILING_ASSISTANT) ;; *) exit 2 ;; esac
shift
source "$root/config/gnome-extensions.lock"
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
curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$zip"
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
