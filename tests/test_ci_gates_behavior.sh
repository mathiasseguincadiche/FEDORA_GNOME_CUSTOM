#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("gate", root / "scripts/ci/check-release-gate.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
sha, repo = "a"*40, "owner/repo"
runs = [dict(id=i+1, path=p, head_sha=sha, head_branch="main", event="push",
             head_repository={"full_name":repo}, status="completed", conclusion="success")
        for i,p in enumerate(sorted(gate.REQUIRED))]
assert gate.check({"workflow_runs":runs},sha,repo)==0
for field,value in (("head_sha","b"*40),("head_branch","other"),("event","pull_request"),
                    ("head_repository",{"full_name":"fork/repo"})):
    changed=json.loads(json.dumps(runs))
    changed[0][field]=value
    assert gate.check({"workflow_runs":changed},sha,repo)==3
for conclusion in ("failure","cancelled","skipped","neutral"):
    changed=json.loads(json.dumps(runs)); changed[0]["conclusion"]=conclusion
    assert gate.check({"workflow_runs":changed},sha,repo)==1
changed=json.loads(json.dumps(runs)); changed[0]["status"]="in_progress"
assert gate.check({"workflow_runs":changed},sha,repo)==3
assert gate.check({"workflow_runs":[]},sha,repo)==3
newer=dict(runs[0],id=100,status="in_progress")
assert gate.check({"workflow_runs":runs+[newer]},sha,repo)==3

# Run the actual audit checker against a synthetic complete catalog. An
# unrelated precheck failure, or a wrong phase/code in an allowed module, fails.
with tempfile.TemporaryDirectory() as temp:
    fixture=pathlib.Path(temp)
    for p in ("scripts/ci","manifests","reports","state"):
        (fixture/p).mkdir(parents=True)
    (fixture/"scripts/ci/check-installer-audit.py").write_text((root/"scripts/ci/check-installer-audit.py").read_text())
    (fixture/"manifests/module-plan.conf").write_text("system.preflight|x\ngnome.core|x\n")
    rows=[dict(module="system.preflight",state="KO",phase="precheck",rc=20,detail="root"),
          dict(module="gnome.core",state="OK",phase="complete",rc=0,detail="complete")]
    def audit(rows, overall="FAIL"):
        (fixture/"reports/run-fixture.json").write_text(json.dumps(dict(mode="dry-run",overall=overall,modules=rows)))
        return subprocess.run([sys.executable,str(fixture/"scripts/ci/check-installer-audit.py"),"20"],
                              env=dict(os.environ,RUN_ID="fixture"),capture_output=True).returncode
    assert audit(rows)==0
    bad=json.loads(json.dumps(rows)); bad[1].update(state="KO",phase="precheck",rc=20)
    assert audit(bad)!=0
    for phase,rc in (("apply",20),("precheck",60),("postcheck",20)):
        bad=json.loads(json.dumps(rows)); bad[0].update(phase=phase,rc=rc)
        assert audit(bad)!=0
    assert audit(rows,"PASS")!=0
print("CI gate behavior: PASS")
PY
