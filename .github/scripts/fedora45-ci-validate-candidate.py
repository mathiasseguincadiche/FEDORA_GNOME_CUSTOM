#!/usr/bin/env python3
"""Read-only candidate validation shared with the production promotion guards."""
import importlib.util
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location("fgc_profile", root / "scripts/development/fedora-profile.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
try:
    profile = module.candidate(root, 45)
except (ValueError, KeyError, FileNotFoundError) as error:
    raise SystemExit(str(error))
print("PASS: pinned GNOME 51 candidates; production profile remains " + profile["status"])
