#!/usr/bin/env python3
"""Offline capability and PCI binding checks; no VA-API device or service used."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("av1_audit", ROOT / "scripts/validation/arc-b580-av1.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ArcAV1Tests(unittest.TestCase):
    def test_vaapi_both_entrypoints_required(self):
        text = """VAProfileAV1Profile0 : VAEntrypointVLD
VAProfileAV1Profile0 : VAEntrypointEncSliceLP
VAProfileH264Main : VAEntrypointEncSlice"""
        self.assertEqual(module.parse_vainfo(text), {"av1_decode": True, "av1_encode": True})
        self.assertFalse(module.parse_vainfo(text.replace("VAEntrypointEncSliceLP", "VAEntrypointVideoProc"))["av1_encode"])
        self.assertFalse(module.parse_vainfo(text.replace("VAEntrypointVLD", "VAEntrypointVideoProc"))["av1_decode"])
        self.assertFalse(module.parse_vainfo("VAProfileH264High : VAEntrypointEncSlice")["av1_encode"])

    def test_requires_b580_pci_and_real_xe_binding(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            driver = root / "drivers/xe"
            driver.mkdir(parents=True)
            node = root / "renderD130/device"
            node.mkdir(parents=True)
            (node / "vendor").write_text("0x8086\n")
            (node / "device").write_text("0xe20b\n")
            (node / "driver").symlink_to(driver)
            self.assertEqual(module.b580_render_nodes(root), ["renderD130"])
            (node / "device").write_text("0xe20c\n")
            self.assertEqual(module.b580_render_nodes(root), [])
            (node / "device").write_text("0xe20b\n")
            other = root / "drivers/i915"
            other.mkdir()
            (node / "driver").unlink()
            (node / "driver").symlink_to(other)
            self.assertEqual(module.b580_render_nodes(root), [])

    def test_no_node_never_claims_sunshine_success(self):
        with tempfile.TemporaryDirectory() as temp:
            report = module.inspect(Path(temp))
            self.assertEqual(report["status"], "NOT_TESTED")
            self.assertEqual(report["sunshine_moonlight_end_to_end"], "NOT_TESTED")
            self.assertEqual(report["hardware_certification"], "DEFERRED")


if __name__ == "__main__":
    unittest.main()
