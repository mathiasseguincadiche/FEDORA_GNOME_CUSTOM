#!/usr/bin/env bash
set -Eeuo pipefail

favorites="${1:-${GNOME_DOCK_FAVORITES:-}}"
[[ -n "$favorites" ]] || { echo 'GNOME dock favorites list is empty' >&2; exit 2; }
command -v gsettings >/dev/null 2>&1 || { echo 'gsettings is unavailable' >&2; exit 3; }
gsettings list-keys org.gnome.shell 2>/dev/null | grep -Fxq favorite-apps || { echo 'org.gnome.shell favorite-apps key is unavailable' >&2; exit 4; }

read -r -a apps <<< "$favorites"
((${#apps[@]} > 0)) || { echo 'No desktop launcher ID parsed' >&2; exit 5; }

for app in "${apps[@]}"; do
  [[ "$app" =~ ^[A-Za-z0-9._-]+\.desktop$ ]] || { echo "Invalid desktop launcher ID: $app" >&2; exit 6; }
done
if printf '%s\n' "${apps[@]}" | sort | uniq -d | grep -q .; then
  echo 'Duplicate desktop launcher ID in favorites' >&2
  exit 7
fi

variant='['
for app in "${apps[@]}"; do
  [[ "$variant" == '[' ]] || variant+=', '
  variant+="'$app'"
done
variant+=']'

gsettings set org.gnome.shell favorite-apps "$variant"
actual="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || true)"
[[ "$actual" == "$variant" ]] || { echo "Dock favorites mismatch: expected $variant, got ${actual:-unavailable}" >&2; exit 8; }
printf '%s\n' "$variant"
