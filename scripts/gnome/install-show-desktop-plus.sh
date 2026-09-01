#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"
uuid="${2:-}"
shell_version="${3:-50}"
[[ -n "$url" && -n "$uuid" ]] || { echo "Usage: $0 <reviewed-zip-url> <uuid> [shell-version]" >&2; exit 2; }
[[ "$url" == 'https://extensions.gnome.org/review/download/70326.shell-extension.zip' ]] || { echo 'Unexpected Show Desktop Plus source URL' >&2; exit 1; }
[[ "$uuid" == 'show-desktop-plus@attentivecoder' ]] || { echo 'Unexpected Show Desktop Plus UUID' >&2; exit 1; }
[[ "$shell_version" == '50' ]] || { echo 'Unexpected GNOME Shell target' >&2; exit 1; }

for cmd in curl unzip grep gnome-extensions glib-compile-schemas; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

zip="$(mktemp --suffix=.zip)"
metadata="$(mktemp)"
trap 'rm -f "$zip" "$metadata"' EXIT

curl --fail --location --proto '=https' --tlsv1.2 "$url" --output "$zip"
unzip -p "$zip" metadata.json > "$metadata"
grep -Fq "\"uuid\": \"$uuid\"" "$metadata" || { echo 'Downloaded extension UUID mismatch' >&2; exit 1; }
grep -Eq "\"${shell_version}\"" "$metadata" || { echo "Downloaded extension is not declared compatible with GNOME Shell $shell_version" >&2; exit 1; }

gnome-extensions install --force "$zip"
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
schema_dir="$extension_dir/schemas"
[[ -r "$extension_dir/metadata.json" ]] || { echo 'Installed Show Desktop Plus metadata missing' >&2; exit 1; }
[[ -d "$schema_dir" ]] || { echo 'Installed Show Desktop Plus schema directory missing' >&2; exit 1; }
glib-compile-schemas "$schema_dir"
printf 'source_url=%s\nreview_id=70326\nsite_version=8\nshell_version=%s\n' "$url" "$shell_version" > "$extension_dir/.fedora-gnome-custom-source"
printf 'Show Desktop Plus installed from GNOME-reviewed artifact: %s\n' "$uuid"
