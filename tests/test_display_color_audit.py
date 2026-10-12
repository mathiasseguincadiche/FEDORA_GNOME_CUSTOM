#!/usr/bin/env python3
"""Offline fixture tests for the privacy-safe display-color diagnostic."""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "diagnostics/display-color-audit.py"
spec = importlib.util.spec_from_file_location("fgc_display_audit", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


class DisplayAuditTests(unittest.TestCase):
    def test_connector_inventory_is_never_color_certification(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            conn = root / "card0-DP-1"
            conn.mkdir()
            (conn / "status").write_text("connected\n")
            (conn / "enabled").write_text("enabled\n")
            (conn / "modes").write_text("2560x1440\n1920x1080\n")
            (conn / "serial").write_text("PRIVATE_MONITOR_SERIAL\n")
            (conn / "edid").write_bytes(b"PRIVATE_EDID_BYTES")
            result = module.audit_connectors(root)
            self.assertEqual(result["hardware_certification"], "DEFERRED")
            self.assertEqual(result["connector_inventory"], "OBSERVED")
            self.assertEqual(result["connectors"][0]["supported_modes_sample"],
                             ["2560x1440", "1920x1080"])
            self.assertTrue(all(v == "NOT_TESTED"
                                for v in result["visual_and_color_checks"].values()))
            self.assertNotIn("PRIVATE", json.dumps(result))
            self.assertNotIn("active_mode", json.dumps(result))
            proc = subprocess.run([sys.executable, str(SCRIPT), "--sysfs-root",
                                   str(root), "--format", "json"],
                                  capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(proc.stdout)["connectors"][0]["status"],
                             "connected")

    def test_empty_or_incomplete_sysfs_does_not_announce_success(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "card0-HDMI-A-1").mkdir()
            self.assertEqual(module.audit_connectors(root)["connector_inventory"],
                             "NOT_TESTED")
            conn = root / "card0-DP-1"
            conn.mkdir()
            (conn / "status").write_text("garbled\n")
            result = module.audit_connectors(root)
            self.assertEqual(result["connectors"][0]["status"], "unknown")
            self.assertEqual(result["hardware_certification"], "DEFERRED")


if __name__ == "__main__":
    unittest.main()
