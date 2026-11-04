#!/usr/bin/env python3
"""Offline behaviour of scripts/ci/check-external-links.py: only a gone page fails."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("links", ROOT / "scripts/ci/check-external-links.py")
links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(links)

for status in (200, 204, 301, 302, 304):
    assert links.classify(status) == "ok", status
for status in (404, 410, None):
    assert links.classify(status) == "broken", status
for status in (401, 403, 405, 429, 500, 502, 503):
    assert links.classify(status) == "warning", status

found = links.collect(ROOT)
assert found and all(url.startswith(("http://", "https://")) for url in found)
assert all("#" not in url for url in found), "fragments are stripped before checking"
print(f"external link checker: PASS (status classes and {len(found)} links collected offline)")
