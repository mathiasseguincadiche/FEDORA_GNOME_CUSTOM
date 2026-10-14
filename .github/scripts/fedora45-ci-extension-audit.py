#!/usr/bin/env python3
"""Read-only GNOME 51 runtime proof for six candidates in a disposable QEMU VM."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
if root != Path("/opt/fgc-lab/repo") or os.geteuid() == 0:
    raise SystemExit("GNOME 51 candidate audit must run as lab user in fixed repository")
if subprocess.check_output(["id", "-un"], text=True).strip() != "lab":
    raise SystemExit("Wrong lab user")
if not Path("/etc/fgc-ci-lab").is_file():
    raise SystemExit("Missing QEMU laboratory marker")
if subprocess.check_output(["hostname"], text=True).strip() != "fgc-fedora-ci":
    raise SystemExit("Wrong QEMU laboratory identity")
if subprocess.check_output(["systemd-detect-virt"], text=True).strip() not in ("kvm", "qemu"):
    raise SystemExit("Wrong virtualization runtime")
if not re.search(r'^VERSION_ID="?45"?$', Path("/etc/os-release").read_text(), re.M):
    raise SystemExit("Fedora 45 expected")
subprocess.run([sys.executable, str(root / ".github/scripts/fedora45-ci-validate-candidate.py"), str(root)],
               check=True, stdout=subprocess.DEVNULL)
spec = importlib.util.spec_from_file_location("gnome51_contract", root / "scripts/validation/gnome51-extension-audit.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
roles = audit.selected_roles(root)
if not re.fullmatch(r"GNOME Shell 51(?:[.][0-9]+)*", audit.run("gnome-shell", "--version").strip()):
    raise SystemExit("GNOME Shell 51 is not running")
active = set(audit.run("gnome-extensions", "list", "--active").splitlines())
enabled = set(audit.run("gnome-extensions", "list", "--enabled").splitlines())
lock = audit.load_profile_module(root).assignments(root / "profiles/fedora45/gnome-extensions.lock")
user_dir = Path.home() / ".local/share/gnome-shell/extensions"
system_dir = Path("/usr/share/gnome-shell/extensions")
metadata, provenance = {}, {}
for role, uuid in roles.items():
    if role in audit.ROLE_UUIDS and (user_dir / uuid).exists():
        raise SystemExit("Forbidden user override of Fedora RPM: " + uuid)
    directory = (system_dir if role in audit.ROLE_UUIDS else user_dir) / uuid
    path = directory / "metadata.json"
    if path.is_file() and not path.is_symlink():
        metadata[uuid] = json.loads(path.read_text())
    if role in audit.LOCK_ROLES:
        marker = directory / ".fedora-gnome-custom-source"
        if marker.is_file() and not marker.is_symlink():
            hashes = [line.removeprefix("sha256=") for line in marker.read_text().splitlines() if line.startswith("sha256=")]
            if len(hashes) == 1:
                provenance[uuid] = hashes[0]
result = audit.assess(roles, active, enabled, metadata, provenance, lock)
result.update(lab_scope="disposable-qemu-only", profile_status="pending",
              production_apply="BLOCKED", physical_gate3="DEFERRED")
print(json.dumps(result, indent=2))
if result["verdict"] != "PASS":
    raise SystemExit(1)
