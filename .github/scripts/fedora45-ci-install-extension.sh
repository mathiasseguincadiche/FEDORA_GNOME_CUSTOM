#!/usr/bin/env bash
# User-scoped test installation in a throwaway Fedora 45 QEMU guest only.
# Never call this from the production installer; it does not validate media.
set -Eeuo pipefail
umask 077
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ "$repo" == /opt/fgc-lab/repo && "$(id -un)" == lab \
  && "$(hostname)" == fgc-fedora-ci && -e /etc/fgc-ci-lab ]] || exit 50
case "$(systemd-detect-virt)" in kvm|qemu) ;; *) exit 50;; esac
grep -Eq '^VERSION_ID="?45"?$' /etc/os-release || exit 50
python3 "$repo/.github/scripts/fedora45-ci-validate-candidate.py" "$repo" >/dev/null
prefix="${1:-}"
case "$prefix" in DING|SHOW_DESKTOP_PLUS|RESOURCE_MONITOR|TILING_ASSISTANT) ;; *) exit 2;; esac
[[ $# -eq 1 ]] || exit 2
# The Python validator rejects shell metacharacters and unexpected assignments.
# shellcheck disable=SC1091
source "$repo/profiles/fedora45/gnome-extensions.lock"
sha_var="${prefix}_SHA256"; uuid_var="${prefix}_UUID"
major_var="${prefix}_SHELL_VERSION"; schema_var="${prefix}_SCHEMA"
url_var="${prefix}_SOURCE_URL"; version_var="${prefix}_VERSION"
zip="/opt/fgc-lab/extensions/$prefix.zip"
[[ -r "$zip" ]] || exit 1
printf '%s  %s\n' "${!sha_var}" "$zip" | sha256sum --check
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
unzip -p "$zip" metadata.json > "$tmp/metadata.json"
python3 "$repo/scripts/gnome/validate-extension-metadata.py" \
  "$tmp/metadata.json" "${!uuid_var}" "${!major_var}"
gnome-extensions install --force "$zip"
dir="$HOME/.local/share/gnome-shell/extensions/${!uuid_var}"
[[ -d "$dir/schemas" ]] || { echo 'Missing extension schema directory' >&2; exit 1; }
# The Tiling Assistant lock intentionally has no *_SCHEMA key. Require an
# exact schema XML when the reviewed lock declares one, as the production
# installer does; always compile the complete schema directory.
if [[ -n "${!schema_var:-}" ]]; then
  [[ -f "$dir/schemas/${!schema_var}.gschema.xml" ]] || exit 1
fi
python3 "$repo/scripts/gnome/validate-extension-metadata.py" \
  "$dir/metadata.json" "${!uuid_var}" "${!major_var}"
glib-compile-schemas "$dir/schemas"
printf 'source_url=%s\nshell_version=%s\nsha256=%s\nsite_version=%s\n' \
  "${!url_var}" "${!major_var}" "${!sha_var}" "${!version_var}" \
  > "$dir/.fedora-gnome-custom-source"
echo "PASS: GNOME 51 candidate installed in disposable guest: ${!uuid_var}"
