#!/usr/bin/env python3
import datetime as dt
import json
from pathlib import Path
import tempfile
import unittest
from importlib.machinery import SourceFileLoader

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/maintenance/weekly-log-cleanup.py"
mod = SourceFileLoader("weekly_cleanup",str(SCRIPT)).load_module()

class RetentionTests(unittest.TestCase):
    def test_retention_and_dry_run(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            logs = root / "logs"
            logs.mkdir()
            now = dt.datetime(2026,10,19,4,tzinfo=dt.timezone.utc)
            old = "20261001T010203000000000Z-123"
            broken = "20261001T010204000000000Z-124"
            fresh = "20261018T010203000000000Z-125"
            for name,content in [(old,"2026-10-01 [INFO] [SYSTEM] Tout va bien"),
                                 (broken,"2026-10-01 [ERROR] [REMOTE] Connexion impossible"),
                                 (fresh,"2026-10-18 [INFO] [SYSTEM] OK")]:
                d = logs / name
                d.mkdir()
                (d/"main.log").write_text(content)
                (d/"modules.log").write_text("")
            mod.scan(root,now,True)
            self.assertTrue((logs/old).exists())
            self.assertFalse((logs/"incidents"/(broken+".json")).exists())
            mod.scan(root,now,False)
            self.assertFalse((logs/old).exists())
            self.assertTrue((logs/broken).exists())
            self.assertTrue((logs/fresh).exists())
            record = logs/"incidents"/(broken+".json")
            self.assertEqual(json.loads(record.read_text())["status"],"open")
            self.assertIn("recommended_action",json.loads(record.read_text()))
            self.assertIn("explanation",json.loads(record.read_text()))
            mod.scan(root,now,False)
            self.assertTrue((logs/broken).exists())
            data=json.loads(record.read_text())
            data["status"]="resolved"
            data["resolution"]="Cause corrigée et testée"
            record.write_text(json.dumps(data))
            mod.scan(root,now,False)
            self.assertFalse((logs/broken).exists())

if __name__ == "__main__":
    unittest.main()
