#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
REPO_ROOT="$ROOT"
source "$ROOT/lib/config.sh"
config_load
for prefix in DING SHOW_DESKTOP_PLUS RESOURCE_MONITOR TILING_ASSISTANT; do
  sha_key="${prefix}_SHA256"; url_key="${prefix}_SOURCE_URL"; uuid_key="${prefix}_UUID"
  [[ "${!sha_key}" =~ ^[0-9a-f]{64}$ && "${!url_key}" == https://* && -n "${!uuid_key}" ]]
done
cp -a "$ROOT/config" "$tmp/config"
printf 'DING_VERSION="999"\n' > "$tmp/config/local.conf"
rc=0
bash "$ROOT/scripts/config/validate-config.sh" "$tmp/config" >/dev/null 2>&1 || rc=$?
[[ "$rc" == 60 ]]
rm "$tmp/config/local.conf"
mkdir -p "$tmp/scripts/gnome" "$tmp/bin" "$tmp/data"
cp "$ROOT/scripts/gnome/"*.sh "$ROOT/scripts/gnome/validate-extension-metadata.py" "$tmp/scripts/gnome/"
export FGC_TEST_ZIP="$tmp/fixture.zip" XDG_DATA_HOME="$tmp/data" FGC_TEST_UUID="$DING_UUID"
python3 - <<'PY'
import json,os,zipfile
with zipfile.ZipFile(os.environ['FGC_TEST_ZIP'], 'w') as z:
    z.writestr('metadata.json', json.dumps({'uuid':os.environ['FGC_TEST_UUID'],'shell-version':['50']}))
    z.writestr('schemas/org.gnome.shell.extensions.ding.gschema.xml','<schemalist/>')
PY
# Changing the lock must invalidate prior configuration-bound evidence.
REPO_ROOT="$tmp"
mkdir -p "$tmp/manifests" "$tmp/virtualization/xml"
source "$ROOT/lib/evidence.sh"
old_hash="$(effective_config_sha256)"
fixture_sha="$(sha256sum "$FGC_TEST_ZIP" | cut -d' ' -f1)"
sed -i "s/^DING_SHA256=.*/DING_SHA256=\"$fixture_sha\"/" "$tmp/config/gnome-extensions.lock"
[[ "$(effective_config_sha256)" != "$old_hash" ]]
cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
cp "$FGC_TEST_ZIP" "${!#}"
SH
cat > "$tmp/bin/gnome-extensions" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p "$XDG_DATA_HOME/gnome-shell/extensions/$FGC_TEST_UUID"
unzip -q "${!#}" -d "$XDG_DATA_HOME/gnome-shell/extensions/$FGC_TEST_UUID"
SH
cat > "$tmp/bin/glib-compile-schemas" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -d "$1" ]]
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
# The real common installer must use the lock's changed digest, not a copied pin.
bash "$tmp/scripts/gnome/install-ding.sh"
marker="$tmp/data/gnome-shell/extensions/$DING_UUID/.fedora-gnome-custom-source"
[[ -s "$marker" ]]
grep -Fxq "sha256=$fixture_sha" "$marker"
rm -rf "$tmp/data/gnome-shell"
printf 'corrupted download' > "$FGC_TEST_ZIP"
if bash "$tmp/scripts/gnome/install-ding.sh" >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$marker" ]]
if bash "$tmp/scripts/gnome/install-ding.sh" https://invalid.example/payload.zip >/dev/null 2>&1; then exit 1; fi
echo 'extension lock and installer behavior: PASS'
