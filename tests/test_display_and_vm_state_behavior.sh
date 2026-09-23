#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import copy, importlib.util, pathlib, sys, tempfile, json
sys.dont_write_bytecode = True
root = pathlib.Path(sys.argv[1])
def load(path):
    spec=importlib.util.spec_from_file_location('tested',root/path)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module
m=load('scripts/gnome/display-state.py')
# Two displays, non-default scale/position, HDR and RGB values.
specs=[['DP-1','ASUS','OLED','serial1'],['HDMI-1','OTHER','LCD','serial2']]
modes=[['2560x1440@240',2560,1440,240.,1.,[1.,1.25],{'is-current':True}]]
state=[12,[(s,copy.deepcopy(modes),{'color-mode':1,'rgb-range':2}) for s in specs],
       [[0,0,1.25,0,True,[specs[0]],{}],[2048,0,1.,0,False,[specs[1]],{}]],
       {'layout-mode':1,'supports-changing-layout-mode':True}]
saved=m.snapshot(state)
assert len(saved['logical'])==2
assert saved['logical'][0][5][0][2]['color-mode']==1
assert saved['logical'][0][2]==1.25
m.validate_restore(saved,state)
assert m.snapshot(state)==saved
changed=copy.deepcopy(state); changed[1].pop()
try: m.validate_restore(saved,changed)
except ValueError: pass
else: raise AssertionError('changed topology accepted')
changed=copy.deepcopy(state);changed[1][0][1][0][0]='unavailable'
try: m.validate_restore(saved,changed)
except ValueError: pass
else: raise AssertionError('unavailable mode accepted')
b=load('scripts/backup/vm-backup-plan.py')
xml='''<domain><uuid>01234567-89ab-cdef-0123-456789abcdef</uuid><os><nvram>/custom/vars.fd</nvram></os><devices><disk type="file" device="disk"><driver type="qcow2"/><source file="/data/a b.qcow2"/><target dev="vda"/></disk><tpm><backend type="emulator"/></tpm></devices></domain>'''
plan=b.plan(xml)
assert plan['disks'][0]['source']=='/data/a b.qcow2'
assert '/custom/vars.fd' in plan['state_paths']
assert '/var/lib/libvirt/swtpm/01234567-89ab-cdef-0123-456789abcdef' in plan['state_paths']
for invalid in [xml.replace('type="qcow2"','type="raw"'),xml.replace('type="emulator"','type="passthrough"')]:
    try: b.plan(invalid)
    except ValueError: pass
    else: raise AssertionError('incomplete VM backup was accepted')
m=load('scripts/performance/measure-workload.py')
with tempfile.TemporaryDirectory() as directory:
    good=pathlib.Path(directory)/'good'; bad=pathlib.Path(directory)/'bad'
    assert m.measure(good,'fixture',3,'commit','config','fingerprint',[sys.executable,'-c','pass'])==0
    assert m.measure(bad,'fixture',3,'commit','config','fingerprint',[sys.executable,'-c','raise SystemExit(42)'])!=0
    assert json.loads((good/'measurements.json').read_text())['verdict']=='PASS'
    failed=json.loads((bad/'measurements.json').read_text())
    assert failed['verdict']=='FAIL' and len(failed['samples'])==1
print('display, VM state and measurement behavior: PASS')
PY
