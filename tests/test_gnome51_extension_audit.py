#!/usr/bin/env python3
"""Offline GNOME 51 role tests: no display server, network or installed extensions."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/validation/gnome51-extension-audit.py"
spec = importlib.util.spec_from_file_location("gnome51_audit", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Gnome51Tests(unittest.TestCase):
    def test_pending_profile_cannot_be_live_pass(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--root", str(ROOT), "--report"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["verdict"], "DEFERRED")
        self.assertEqual(len(report["expected_roles"]), 6)
        live = subprocess.run([sys.executable, str(SCRIPT), "--root", str(ROOT), "--live"],
                              capture_output=True, text=True)
        self.assertNotEqual(live.returncode, 0)
        self.assertEqual(json.loads(live.stdout)["verdict"], "FAIL")

    def test_strict_runtime_pass_and_negative_cases(self):
        roles = {"dash": "dash-to-dock@micxgx.gmail.com",
                 "appindicator": "appindicatorsupport@rgcjonas.gmail.com",
                 "desktop_icons": "gtk4-ding@smedius.gitlab.com",
                 "show_desktop": "show-desktop-button@amivaleo",
                 "telemetry": "Vitals@CoreCoding.com",
                 "tiling": "tiling-assistant@leleat-on-github"}
        lock = {key + "_SHA256": "a" * 64 for key in module.LOCK_ROLES.values()}
        metadata = {uid: {"uuid": uid, "shell-version": ["51"]} for uid in roles.values()}
        provenance = {uid: "a" * 64 for key, uid in roles.items() if key in module.LOCK_ROLES}
        wanted = set(roles.values())
        def check(active=wanted, enabled=wanted, meta=metadata, proof=provenance):
            return module.assess(roles, active, enabled, meta, proof, lock)
        self.assertEqual(check()["verdict"], "PASS")
        self.assertEqual(check(active=wanted - {roles["dash"]})["verdict"], "FAIL")
        self.assertEqual(check(enabled=wanted - {roles["telemetry"]})["verdict"], "FAIL")
        self.assertEqual(check(active=wanted | module.DISALLOWED)["verdict"], "FAIL")
        self.assertEqual(check(proof={})["verdict"], "FAIL")
        mismatch = dict(metadata)
        mismatch[roles["tiling"]] = {"uuid": roles["tiling"], "shell-version": ["50"]}
        self.assertEqual(check(meta=mismatch)["verdict"], "FAIL")


if __name__ == "__main__":
    unittest.main()
