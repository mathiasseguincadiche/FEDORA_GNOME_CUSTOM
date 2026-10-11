#!/usr/bin/env bash
# Real selected-release guards plus a temporary promoted-profile fixture.
# shellcheck disable=SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
REPO_ROOT="$ROOT"
source "$ROOT/lib/fedora_release.sh"
FEDORA_OS_RELEASE_FILE="$tmp/os-release"
printf 'ID=fedora\nVERSION_ID="44"\n' > "$FEDORA_OS_RELEASE_FILE"
HOST_RELEASE=44
fedora_require_selected
fedora_shell_matches 'GNOME Shell 50.4'
if fedora_shell_matches 'GNOME Shell 51.0'; then exit 1; fi
HOST_RELEASE=45
if fedora_require_selected; then echo 'pending Fedora 45 accepted' >&2; exit 1; fi
HOST_RELEASE=46
if fedora_require_profile; then exit 1; fi
python3 - "$ROOT" "$tmp" <<'PY'
import hashlib, importlib.util, json, pathlib, sys
root, work=map(pathlib.Path,sys.argv[1:])
spec=importlib.util.spec_from_file_location("profile",root/"scripts/development/fedora-profile.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for directory in ("profiles/fedora45","installer","config"): (work/directory).mkdir(parents=True,exist_ok=True)
packages=work/"profiles/fedora45/packages-nautilus.txt"
packages.write_bytes((root/"profiles/fedora45/packages-nautilus.txt").read_bytes())
canonical=(root/"config/gnome-extensions.lock").read_text()
(work/"config/gnome-extensions.lock").write_text(canonical)
(work/"installer/fedora44-media.lock").write_bytes((root/"installer/fedora44-media.lock").read_bytes())
extensions=work/"profiles/fedora45/gnome-extensions.lock"
reviewed=(root/"profiles/fedora45/gnome-extensions.lock").read_text()
extensions.write_text(reviewed)
media=work/"installer/fedora45-media.lock"
media.write_text('FEDORA_RELEASE=45\nFEDORA_COMPOSE=1.1\nCHECKSUM_FILENAME=Fedora-Workstation-45-1.1-x86_64-CHECKSUM\nSOURCE_URL=https://fedoraproject.org/workstation/download/\nVERIFIED_UTC=2026-10-20T00:00:00Z\nRELEASE_STATUS=final\nISO_FILENAME=Fedora-Workstation-Live-45-1.1.x86_64.iso\nISO_SHA256='+ "a"*64+'\nSIGNING_FINGERPRINT=4F50A6114CD5C6976A7F1179655A4B02F577861E\n')
manifest=work/"profiles/fedora45/profile.json"
def seal():
    manifest.write_text(json.dumps({"schema":1,"release":45,"gnome_major":51,"status":"ready",
        "media_lock_sha256":hashlib.sha256(media.read_bytes()).hexdigest(),
        "extensions_lock_sha256":hashlib.sha256(extensions.read_bytes()).hexdigest(),
        "packages_lock_sha256":hashlib.sha256(packages.read_bytes()).hexdigest(),
        "promotion_source_commit":"b"*40}))
seal(); m.validate(work,45)
def rejected():
    try: m.validate(work,45)
    except ValueError: pass
    else: raise AssertionError("invalid profile accepted")
extensions.write_text(extensions.read_text()+'PATH="/tmp"\n');seal();rejected()
extensions.write_text(reviewed)
media.write_text(media.read_text().replace("RELEASE_STATUS=final","RELEASE_STATUS=beta"));seal();rejected()
media.write_text(media.read_text().replace("RELEASE_STATUS=beta","RELEASE_STATUS=final"));seal()
extensions.write_text(extensions.read_text().replace('DING_SHELL_VERSION="51"','DING_SHELL_VERSION="50"'));seal();rejected()
extensions.write_text(reviewed);seal()
# The original identities stay acceptable (a native build may appear), unreviewed ones never are.
original=canonical.replace('_SHELL_VERSION="50"','_SHELL_VERSION="51"')
extensions.write_text(original);seal();m.validate(work,45)
extensions.write_text(reviewed.replace("gtk4-ding@smedius.gitlab.com","evil@example.com"));seal();rejected()
extensions.write_text(reviewed.replace('DING_SCHEMA="org.gnome.shell.extensions.gtk4-ding"','DING_SCHEMA="org.gnome.shell.extensions.ding"'));seal();rejected()
extensions.write_text(reviewed);seal()
extensions.write_text(extensions.read_text()+"# changed after qualification\n");rejected()
print("Fedora release behavior: PASS")
PY
