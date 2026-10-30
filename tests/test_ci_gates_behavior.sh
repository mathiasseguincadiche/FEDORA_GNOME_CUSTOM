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
# A failed security scan blocks the release like any other required workflow.
security=".github/workflows/security-scanning.yml"
assert security in gate.REQUIRED
changed=json.loads(json.dumps(runs))
for run in changed:
    if run["path"]==security: run["conclusion"]="failure"
assert gate.check({"workflow_runs":changed},sha,repo)==1
assert gate.check({"workflow_runs":[r for r in runs if r["path"]!=security]},sha,repo)==3

# Every workflow that runs on each push to main gates the release. A paths
# filter, a branch filter that excludes main, or a tags-only trigger means the
# workflow does not run on every main commit, so it cannot gate the release.
def push_filters(text):
    """Return the push trigger's filters as {key: [values]}, or None without push."""
    lines=text.splitlines()
    try: start=lines.index("on:")
    except ValueError: return None
    block=[]
    for line in lines[start+1:]:
        if line and not line.startswith(" "): break
        block.append(line)
    for i,line in enumerate(block):
        if line.strip().startswith("push:"):
            indent=len(line)-len(line.lstrip())
            filters, key = {}, None
            for sub in block[i+1:]:
                if not sub.strip(): continue
                if len(sub)-len(sub.lstrip())<=indent: break
                item=sub.strip()
                if item.startswith("- ") and key:
                    filters[key].append(item[2:].strip().strip("'\""))
                elif ":" in item:
                    key, value = (part.strip() for part in item.split(":", 1))
                    filters[key]=[v.strip().strip("'\"") for v in value.strip("[]").split(",") if v.strip()]
            return filters
    return None
def runs_on_every_main_push(text):
    filters=push_filters(text)
    if filters is None or "paths" in filters or "paths-ignore" in filters: return False
    if "main" in filters.get("branches-ignore", []): return False
    if "branches" in filters: return "main" in filters["branches"]
    return "tags" not in filters
samples={
    "on:\n  push:\n": True,
    "on:\n  push:\n    branches: [main]\n": True,
    "on:\n  push:\n    branches:\n      - main\n": True,
    "on:\n  push:\n    branches: [develop]\n": False,
    "on:\n  push:\n    branches-ignore: [main]\n": False,
    "on:\n  push:\n    tags: ['v*']\n": False,
    "on:\n  push:\n    branches: [main]\n    paths:\n      - 'docs/**'\n": False,
    "on:\n  pull_request:\n": False,
}
for sample, expected in samples.items():
    assert runs_on_every_main_push(sample) is expected, sample
workflows={".github/workflows/"+f.name for f in (root/".github/workflows").glob("*.yml")
           if runs_on_every_main_push(f.read_text(encoding="utf-8"))}
missing=workflows-gate.REQUIRED
assert not missing, f"push workflows missing from the release gate: {sorted(missing)}"
assert gate.REQUIRED<=workflows|{".github/workflows/"+f.name for f in (root/".github/workflows").glob("*.yml")}, "unknown workflow in the release gate"

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
