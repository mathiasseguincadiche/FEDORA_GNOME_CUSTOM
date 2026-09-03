#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"
uuid="${2:-}"
shell_version="${3:-50}"
expected_sha256="18f49cf20bd8f96f22f6048d7404e51cb414c1aea94ca16d0c2ad3634e9d8bf2"
[[ -n "$url" && -n "$uuid" ]] || { echo "Usage: $0 <reviewed-zip-url> <uuid> [shell-version]" >&2; exit 2; }
[[ "$url" == 'https://extensions.gnome.org/review/download/70909.shell-extension.zip' ]] || { echo 'Unexpected Resource Monitor source URL' >&2; exit 1; }
[[ "$uuid" == 'Resource_Monitor@Ory0n' ]] || { echo 'Unexpected Resource Monitor UUID' >&2; exit 1; }
[[ "$shell_version" == '50' ]] || { echo 'Unexpected GNOME Shell target' >&2; exit 1; }

for cmd in curl unzip grep sha256sum gnome-extensions glib-compile-schemas; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

zip="$(mktemp --suffix=.zip)"
metadata="$(mktemp)"
trap 'rm -f "$zip" "$metadata"' EXIT

curl --fail --location --proto '=https' --tlsv1.2 "$url" --output "$zip"
printf '%s  %s\n' "$expected_sha256" "$zip" | sha256sum --check --status || { echo 'Downloaded Resource Monitor SHA-256 mismatch' >&2; exit 1; }
unzip -p "$zip" metadata.json > "$metadata"
grep -Fq "\"uuid\": \"$uuid\"" "$metadata" || { echo 'Downloaded Resource Monitor UUID mismatch' >&2; exit 1; }
grep -Eq "\"${shell_version}\"" "$metadata" || { echo "Downloaded Resource Monitor is not declared compatible with GNOME Shell $shell_version" >&2; exit 1; }

gnome-extensions install --force "$zip"
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
schema_dir="$extension_dir/schemas"
[[ -r "$extension_dir/metadata.json" ]] || { echo 'Installed Resource Monitor metadata missing' >&2; exit 1; }
[[ -r "$schema_dir/org.gnome.shell.extensions.resource-monitor.gschema.xml" ]] || { echo 'Installed Resource Monitor GSettings schema missing' >&2; exit 1; }
glib-compile-schemas "$schema_dir"
printf 'source_url=%s\nreview_id=70909\nsite_version=28\nshell_version=%s\nsha256=%s\n' "$url" "$shell_version" "$expected_sha256" > "$extension_dir/.fedora-gnome-custom-source"
printf 'Resource Monitor installed from GNOME-reviewed artifact: %s\n' "$uuid"
