#!/usr/bin/env bash
# Exercise actual downloaded ZIP validation, API success with invalid payload,
# incorrect UUID/major, missing schemas and pending-profile rejection.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import importlib.util, io, json, pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("readiness", root / "scripts/development/release-readiness.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def archive(uuid="ding@rastersoft.com", shell="51", schemas=True):
    result=io.BytesIO()
    with zipfile.ZipFile(result,"w") as z:
        z.writestr("metadata.json",json.dumps({"uuid":uuid,"shell-version":[shell]}))
        if schemas: z.writestr("schemas/test.gschema.xml","<schemalist/>")
    return result.getvalue()
def transport(data):
    return lambda url: json.dumps({"version":97,"version_tag":80001}).encode() if "extension-info" in url else data
candidate=m.ego_candidate("ding@rastersoft.com",51,transport(archive()))
assert candidate["SHELL_VERSION"]=="51" and len(candidate["SHA256"])==64
for data in (b"not a zip",archive(shell="50"),archive(uuid="wrong"),archive(schemas=False)):
    try: m.ego_candidate("ding@rastersoft.com",51,transport(data))
    except (ValueError,zipfile.BadZipFile): pass
    else: raise AssertionError("API availability falsely called compatible")
try: m.profile.validate(root,45)
except ValueError as error: assert "pending" in str(error)
else: raise AssertionError("unqualified future profile accepted")
source=(root / "scripts/development/release-readiness.py").read_text()
assert 'skipped work is BLOCKED' in source
assert '"status": "BLOCKED" if blocked else "READY"' in source
assert "candidate-gnome-extensions.lock" in source
print("release readiness behavior: PASS")
PY
