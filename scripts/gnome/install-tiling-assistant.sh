#!/usr/bin/env bash
# Install Tiling Assistant (Ubuntu "Enhanced Tiling") from its pinned upstream
# GitHub release. The download is refused unless URL, UUID, SHA-256 and the
# declared GNOME Shell compatibility all match the versioned contract.
set -Eeuo pipefail

url="${1:-}"
uuid="${2:-}"
shell_version="${3:-50}"
expected_sha256="7bc50a3bc597c8a6fb45f900040aa7696864ec1b2ce494b569c7b22303b30b26"
expected_url='https://github.com/Leleat/Tiling-Assistant/releases/download/v55/tiling-assistant@leleat-on-github.shell-extension.zip'
[[ -n "$url" && -n "$uuid" ]] || { echo "Usage: $0 <release-zip-url> <uuid> [shell-version]" >&2; exit 2; }
[[ "$url" == "$expected_url" ]] || { echo 'Unexpected Tiling Assistant source URL' >&2; exit 1; }
[[ "$uuid" == 'tiling-assistant@leleat-on-github' ]] || { echo 'Unexpected Tiling Assistant UUID' >&2; exit 1; }
[[ "$shell_version" == '50' ]] || { echo 'Unexpected GNOME Shell target' >&2; exit 1; }

for cmd in curl unzip grep sha256sum gnome-extensions glib-compile-schemas; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

zip="$(mktemp --suffix=.zip)"
metadata="$(mktemp)"
trap 'rm -f "$zip" "$metadata"' EXIT

curl --fail --location --proto '=https' --tlsv1.2 "$url" --output "$zip"
printf '%s  %s\n' "$expected_sha256" "$zip" | sha256sum --check --status || { echo 'Downloaded Tiling Assistant SHA-256 mismatch' >&2; exit 1; }
unzip -p "$zip" metadata.json > "$metadata"
grep -Fq "\"uuid\": \"$uuid\"" "$metadata" || { echo 'Downloaded extension UUID mismatch' >&2; exit 1; }
grep -Eq "\"${shell_version}\"" "$metadata" || { echo "Downloaded extension is not declared compatible with GNOME Shell $shell_version" >&2; exit 1; }

gnome-extensions install --force "$zip"
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
schema_dir="$extension_dir/schemas"
[[ -r "$extension_dir/metadata.json" ]] || { echo 'Installed Tiling Assistant metadata missing' >&2; exit 1; }
[[ -d "$schema_dir" ]] && glib-compile-schemas "$schema_dir"
printf 'source_url=%s\nrelease=v55\nshell_version=%s\nsha256=%s\n' "$url" "$shell_version" "$expected_sha256" > "$extension_dir/.fedora-gnome-custom-source"
printf 'Tiling Assistant installed from pinned GitHub release: %s\n' "$uuid"
