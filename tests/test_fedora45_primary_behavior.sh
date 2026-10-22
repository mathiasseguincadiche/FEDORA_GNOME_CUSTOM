#!/usr/bin/env bash
# Real read-only selection, explicit legacy selection and fail-closed pending installs.
# shellcheck disable=SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "Fedora 45 primary behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/repo/scripts/config" "$tmp/repo/scripts/development" "$tmp/repo/scripts/gnome" "$tmp/repo/manifests" "$tmp/bin"
cp -a "$ROOT/config" "$ROOT/lib" "$ROOT/profiles" "$tmp/repo/"
cp "$ROOT/scripts/config/validate-config.sh" "$tmp/repo/scripts/config/"
cp "$ROOT/scripts/development/fedora-profile.py" "$tmp/repo/scripts/development/"
cp "$ROOT/scripts/gnome/install-pinned-extension.sh" "$tmp/repo/scripts/gnome/"
cp "$ROOT/manifests/packages-nautilus.txt" "$tmp/repo/manifests/"
rm -f "$tmp/repo/config/local.conf"
printf '{"schema":1,"release":45,"gnome_major":51,"status":"pending"}\n' > "$tmp/repo/profiles/fedora45/profile.json"
REPO_ROOT="$tmp/repo"
source "$REPO_ROOT/lib/config.sh"
config_load
[[ "$HOST_RELEASE" == 45 && "$(fedora_expected_gnome_major)" == 51 ]] || fail 'wrong default release'
[[ "$DING_UUID" == gtk4-ding@smedius.gitlab.com && "$RESOURCE_MONITOR_UUID" == Vitals@CoreCoding.com && "$SHOW_DESKTOP_PLUS_UUID" == show-desktop-button@amivaleo ]] || fail 'wrong default extension identities'
fedora_shell_matches 'GNOME Shell 51.0' || fail 'GNOME 51 refused'
if fedora_shell_matches 'GNOME Shell 50.5'; then fail 'GNOME 50 accepted for primary'; fi
python3 "$REPO_ROOT/scripts/development/fedora-profile.py" candidate "$REPO_ROOT" 45
[[ "$(fedora_manifest_path "$REPO_ROOT/manifests/packages-nautilus.txt")" == "$REPO_ROOT/manifests/packages-nautilus.txt" ]] || fail 'primary manifest not selected'
if fedora_require_profile; then fail 'pending profile accepted for production'; fi
# Installer refuses before a download or activation, even when called outside install.sh.
cat > "$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
touch "$FGC_DOWNLOAD_TRACE"
exit 99
STUB
chmod +x "$tmp/bin/curl"
export FGC_DOWNLOAD_TRACE="$tmp/download"
if PATH="$tmp/bin:$PATH" bash "$REPO_ROOT/scripts/gnome/install-pinned-extension.sh" DING > "$tmp/install.log" 2>&1; then fail 'pending installer succeeded'; fi
grep -qi pending "$tmp/install.log" || fail 'installer failed for a different reason'
[[ ! -e "$FGC_DOWNLOAD_TRACE" ]] || fail 'installer downloaded while pending'
# Only an explicit local override selects the archived identities and manifest.
printf 'HOST_RELEASE="44"\n' > "$REPO_ROOT/config/local.conf"
config_load
[[ "$HOST_RELEASE" == 44 && "$DING_UUID" == ding@rastersoft.com && "$(fedora_expected_gnome_major)" == 50 ]] || fail 'explicit legacy selection broken'
[[ "$(fedora_manifest_path "$REPO_ROOT/manifests/packages-nautilus.txt")" == "$REPO_ROOT/profiles/fedora44/packages-nautilus.txt" ]] || fail 'legacy manifest not selected'
if fedora_require_install_target; then fail 'legacy selected for production'; fi
# Candidate parity failures are errors, never an implicit promotion.
printf '\nfile-roller\n' >> "$REPO_ROOT/manifests/packages-nautilus.txt"
if python3 "$REPO_ROOT/scripts/development/fedora-profile.py" candidate "$REPO_ROOT" 45 >/dev/null 2>&1; then fail 'divergent manifests accepted'; fi
cp "$ROOT/manifests/packages-nautilus.txt" "$REPO_ROOT/manifests/"
for lock in "$REPO_ROOT/config/gnome-extensions.lock" "$REPO_ROOT/profiles/fedora45/gnome-extensions.lock"; do
  printf '\nPATH="/unreviewed"\n' >> "$lock"
done
if python3 "$REPO_ROOT/scripts/development/fedora-profile.py" candidate "$REPO_ROOT" 45 >/dev/null 2>&1; then fail 'unknown keys accepted in both locks'; fi
for lock in "$REPO_ROOT/config/gnome-extensions.lock" "$REPO_ROOT/profiles/fedora45/gnome-extensions.lock"; do sed -i '/^PATH=/d' "$lock"; done
sed -i 's/DING_VERSION="145"/DING_VERSION="999"/' "$REPO_ROOT/config/gnome-extensions.lock"
if python3 "$REPO_ROOT/scripts/development/fedora-profile.py" candidate "$REPO_ROOT" 45 >/dev/null 2>&1; then fail 'divergent extension locks accepted'; fi
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$REPO_ROOT/profiles/fedora45/profile.json")" == pending ]] || fail 'candidate check promoted profile'
python3 - "$ROOT" <<'PY_CI'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for name in ('tests', 'fedora-host-pretest', 'fedora-package-preflight', 'desktop-integration-pretest',
             'fedora-appimage-pretest', 'fedora-gaming-pretest', 'resource-monitor-fedora-pretest'):
    workflow = (root / '.github/workflows' / (name + '.yml')).read_text()
    assert 'container: registry.fedoraproject.org/fedora:45' in workflow, name
    assert workflow.count('uses: actions/checkout@') == workflow.count('ref: ${{ github.event.pull_request.head.sha || github.sha }}'), name
legacy = (root / '.github/workflows/fedora44-legacy-lab.yml').read_text()
assert 'workflow_dispatch:' in legacy and 'pull_request:' not in legacy and 'workflow_call:' not in legacy
assert 'fedora44-legacy-lab.yml' not in (root / '.github/workflows/tests.yml').read_text()
assert "FGC_LAB_RELEASE: '45'" in (root / '.github/workflows/fedora-gnome-vm.yml').read_text()
PY_CI
echo 'Fedora 45 primary behavior: PASS'
