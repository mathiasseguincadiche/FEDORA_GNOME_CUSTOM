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
# Individual extension info checks have already confirmed all six ACTIVE;
# re-query all enabled/active IDs so the strict audit can reject unexpected
# extensions. Require a successful CLI response rather than interpreting a
# transient D-Bus exit=2 as an empty or healthy list.
list_spec = importlib.util.spec_from_file_location(
    "gnome51_lab_extension_list", root / ".github/scripts/fedora45-ci-extension-list.py"
)
extension_list = importlib.util.module_from_spec(list_spec)
list_spec.loader.exec_module(extension_list)
active = extension_list.list_extensions("--active")
enabled = extension_list.list_extensions("--enabled")
lock = audit.load_profile_module(root).assignments(root / "profiles/fedora45/gnome-extensions.lock")
variant = os.environ.get("FGC_LAB_DING_VARIANT", "production")
if variant == "gtk4-v148":
    candidate = audit.load_profile_module(root).assignments(root / ".github/gtk4-ding-v148.lab.lock")
    if set(candidate) != {"DING_SOURCE_URL", "DING_REVIEW_ID", "DING_VERSION", "DING_SHA256"}:
        raise SystemExit("Unexpected DING candidate lock fields")
    lock.update(candidate)
elif variant != "production":
    raise SystemExit("Unsupported DING laboratory variant")
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
# A nominal ACTIVE state cannot prove this crash-race correction. Reconstruct
# dingManager.js from the reviewed ZIP and compare every byte after patching.
if variant == "production":
    subprocess.run(
        [sys.executable, str(root / ".github/scripts/fedora45-ci-ding-shutdown-fix.py"), "verify"],
        check=True, stdout=subprocess.DEVNULL,
    )
else:
    # Candidate is upstream-only. Verify the pinned archive and every byte of
    # the installed manager against it, never treat the v145 patch as applicable.
    import hashlib
    import zipfile
    archive = Path("/opt/fgc-lab/extensions/DING.zip")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != lock["DING_SHA256"]:
        raise SystemExit("DING candidate ZIP mismatch")
    directory = user_dir / roles["desktop_icons"]
    with zipfile.ZipFile(archive) as z:
        managers = [name for name in z.namelist() if Path(name).name == "dingManager.js"]
        if len(managers) != 1:
            raise SystemExit("DING candidate manager ambiguous")
        manager = directory / managers[0]
        if directory.is_symlink() or manager.is_symlink() or not manager.is_file() or manager.read_bytes() != z.read(managers[0]):
            raise SystemExit("DING candidate manager differs from upstream ZIP")
subprocess.run([sys.executable, str(root / "scripts/gnome/fedora45-rpm-extensions.py"), "--verify"], check=True)
result = audit.assess(roles, active, enabled, metadata, provenance, lock)
profile_status = json.loads((root / "profiles/fedora45/profile.json").read_text())["status"]
result.update(lab_scope="disposable-qemu-only", profile_status=profile_status,
              ding_variant=variant, ding_archive_sha256=lock["DING_SHA256"],
              production_apply="BLOCKED", physical_gate3="DEFERRED")
print(json.dumps(result, indent=2))
if result["verdict"] != "PASS":
    raise SystemExit(1)
