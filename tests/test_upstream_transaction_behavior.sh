#!/usr/bin/env bash
# Real TOML generation: preserve unrelated rules, refuse RC/custom/overlapping
# administrator locks, replace the managed target without duplicate sections.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import importlib.util,pathlib,sys,tomllib
root=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location("pin",root/"scripts/kernel/pin-upstream-target.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
other='version = "1.0"\n\n[[packages]]\nname = "bash"\n[[packages.conditions]]\nkey = "evr"\ncomparator = "="\nvalue = "0:5.3-1.fc44"\n'
text=m.render(other,"7.2.9-200.vanilla.fc44.x86_64")
assert text.startswith(other.rstrip()) and text.count(m.START)==1
entries=tomllib.loads(text)["packages"]
assert len(entries)==6 and entries[0]["name"]=="bash"
for item in entries[1:]:
    assert item["conditions"]==[{"key":"evr","comparator":"=","value":"0:7.2.9-200.vanilla.fc44"},{"key":"arch","comparator":"=","value":"x86_64"}]
assert m.render(text,"--clear")==other.rstrip()+"\n"
next_text=m.render(text,"7.3-300.vanilla.fc45.x86_64")
assert next_text.count(m.START)==1 and "7.2.9" not in next_text
for release in ("7.3.0-0.rc6.vanilla.fc45.x86_64","7.2.9-200.fc44.x86_64","7.2.9-200.vanilla.fc46.x86_64","bad"):
    try:m.render(other,release)
    except ValueError:pass
    else:raise AssertionError("invalid target accepted")
for name in ("kernel*","kernel-core","*"):
    overlap=other.replace('name = "bash"','name = "'+name+'"')
    try:m.render(overlap,"7.2.9-200.vanilla.fc44.x86_64")
    except ValueError:pass
    else:raise AssertionError("administrator kernel rule overwritten")
for source in ('version = "2.0"\n',other+m.START+"\n"):
    try:m.render(source,"7.2.9-200.vanilla.fc44.x86_64")
    except ValueError:pass
    else:raise AssertionError("invalid versionlock file accepted")
for path in ("lib/kernel_lifecycle.sh","scripts/maintenance/update-system.sh","scripts/maintenance/upgrade-fedora.sh"):
    assert "kernel_lifecycle_pin_target" in (root/path).read_text()
print("upstream transaction behavior: PASS")
PY
