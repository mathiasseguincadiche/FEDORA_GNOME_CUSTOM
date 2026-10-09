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
# Replacement-candidate probe: reports facts from the real archive, rejects wrong major / no build.
def probe_archive(shell="51"):
    result=io.BytesIO()
    with zipfile.ZipFile(result,"w") as z:
        z.writestr("metadata.json",json.dumps({"uuid":"Vitals@CoreCoding.com","shell-version":[shell]}))
        z.writestr("schemas/x.gschema.xml",'<schemalist><schema id="org.example.v"><key name="a" type="b"/></schema></schemalist>')
    return result.getvalue()
def probe_transport(info, data):
    return lambda url: json.dumps(info).encode() if "extension-info" in url else data
good=m.probe_candidate(1460,51,probe_transport({"uuid":"Vitals@CoreCoding.com","version":85,"version_tag":90001,"name":"Vitals"},probe_archive()))
assert good["schemas"]=={"org.example.v":["a:b"]} and len(good["sha256"])==64 and good["review_id"]=="90001"
for info,data in (({"uuid":"Vitals@CoreCoding.com","version":85},probe_archive()),
                  ({"uuid":"Vitals@CoreCoding.com","version_tag":90001},probe_archive("50"))):
    try: m.probe_candidate(1460,51,probe_transport(info,data))
    except ValueError: pass
    else: raise AssertionError("probe accepted a candidate without a GNOME 51 build")
try: m.profile.validate(root,45)
except ValueError as error: assert "pending" in str(error)
else: raise AssertionError("unqualified future profile accepted")
uuid="tiling-assistant@leleat-on-github"
tiling_url="https://github.com/ubuntu/Tiling-Assistant/releases/download/v55/tiling-assistant%40leleat-on-github.shell-extension.zip"
release={"tag_name":"v55","prerelease":False,"draft":False,"assets":[{"name":uuid+".shell-extension.zip","browser_download_url":tiling_url}]}
def tiling_transport(url):
    return json.dumps(release).encode() if "api.github.com" in url else archive(uuid=uuid)
assert m.tiling_candidate(uuid,51,tiling_transport)["SOURCE_URL"]==tiling_url
release["assets"][0]["browser_download_url"]="https://github.com/untrusted/Tiling-Assistant/releases/download/v55/extension.zip"
try: m.tiling_candidate(uuid,51,tiling_transport)
except ValueError: pass
else: raise AssertionError("untrusted Tiling publisher accepted")
source=(root / "scripts/development/release-readiness.py").read_text()
assert 'skipped work is BLOCKED' in source
assert '"status": "BLOCKED" if blocked else "READY"' in source
assert "candidate-gnome-extensions.lock" in source
print("release readiness behavior: PASS")
PY
