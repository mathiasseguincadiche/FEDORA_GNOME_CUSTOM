#!/usr/bin/env python3
"""Validate GNOME 51 candidate data without promoting a pending Fedora release."""
import importlib.util
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location("fgc_profile", root / "scripts/development/fedora-profile.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
profile = json.loads((root / "profiles/fedora45/profile.json").read_text())
if (profile.get("status"), profile.get("release"), profile.get("gnome_major")) != ("pending", 45, 51):
    raise SystemExit("This preview exercises only pending Fedora 45; no production promotion")
lock = module.assignments(root / "profiles/fedora45/gnome-extensions.lock")
canonical = module.assignments(root / "config/gnome-extensions.lock")
if set(lock) != set(canonical):
    raise SystemExit("Unreviewed candidate lock keys")
for prefix in ("DING", "SHOW_DESKTOP_PLUS", "RESOURCE_MONITOR", "TILING_ASSISTANT"):
    if lock.get(prefix + "_SHELL_VERSION") != "51":
        raise SystemExit("GNOME 51 identity mismatch: " + prefix)
    if not re.fullmatch("[0-9a-f]{64}", lock.get(prefix + "_SHA256", "")):
        raise SystemExit("Invalid candidate digest: " + prefix)
    for suffix in ("UUID", "SCHEMA"):
        allowed = {canonical[prefix + "_" + suffix]}
        if prefix in module.REPLACEMENTS:
            allowed.add(module.REPLACEMENTS[prefix][0 if suffix == "UUID" else 1])
        if lock[prefix + "_" + suffix] not in allowed:
            raise SystemExit("Unreviewed candidate identity: " + prefix)
    url = lock.get(prefix + "_SOURCE_URL", "")
    if not url.startswith((
        "https://extensions.gnome.org/review/download/",
        "https://github.com/ubuntu/Tiling-Assistant/releases/download/",
        "https://github.com/Leleat/Tiling-Assistant/releases/download/")):
        raise SystemExit("Unreviewed candidate URL: " + prefix)
print("PASS: pinned GNOME 51 candidates; production profile remains pending")
