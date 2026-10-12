#!/usr/bin/env python3
"""Adversarial tests of non-executable Rocky bootstrap completion evidence."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rocky_marker", ROOT / "guest/rocky-devops/verify-bootstrap-marker.py")
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
BASE = """completed_at=2026-10-01T09:05:00Z
kubernetes_minor=v1.37
kubernetes_release=v1.37.3
kind_version=v0.33.0
minikube_version=v1.38.1
node_version=v22.19.1
java_version=javac 21.0.8
yq_version=v4.53.3
k9s_version=v0.51.0
rpm_release=10.2
helm_version=v4.3.0
"""

class EvidenceTests(unittest.TestCase):
    def test_valid_marker(self):
        self.assertEqual(tool.verify(BASE)["rpm_release"], "10.2")

    def test_refuse_fake_or_stale(self):
        modified = [
            BASE.replace("rpm_release=10.2", "rpm_release=9.6"),
            BASE.replace("kind_version=v0.33.0", "kind_version=v0.32.0"),
            BASE.replace("kubernetes_release=v1.37.3", "kubernetes_release=v1.36.8"),
            BASE.replace("node_version=v22.19.1", "node_version=v20.0.0"),
            BASE.replace("java_version=javac 21.0.8", "java_version=javac 17.0.1"),
            BASE.replace("helm_version=v4.3.0", "helm_version=latest"),
            BASE.replace("completed_at=2026-10-01T09:05:00Z", "completed_at=2099-10-01T09:05:00Z"),
            BASE.replace("yq_version=v4.53.3\n", ""),
            BASE + "kind_version=v0.33.0\n",
            BASE + "PASSWORD=never-print\n",
            BASE.replace("k9s_version=v0.51.0", "k9s_version=v0.51.0$(id)"),
        ]
        for item in modified:
            with self.subTest(item=item):
                with self.assertRaises(ValueError):
                    tool.verify(item)

    def test_symlink_and_missing_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            f = root / "marker"
            f.write_text(BASE)
            self.assertEqual(tool.main([str(f)]), 0)
            link = root / "link"
            link.symlink_to(f)
            self.assertEqual(tool.main([str(link)]), 1)
            self.assertEqual(tool.main([str(root / "missing")]), 1)

if __name__ == "__main__":
    unittest.main()
