#!/usr/bin/env python3
"""Exercise the journal classifier with exact, spoofed and malformed entries."""
import json
import pathlib
import subprocess
import sys

classifier = pathlib.Path(__file__).resolve().parents[1] / ".github/scripts/rocky-guest-health.py"

def run(entries, expected, raw=None):
    data = raw if raw is not None else "".join(json.dumps(e) + "\n" for e in entries)
    result = subprocess.run([sys.executable, str(classifier)], input=data,
                            text=True, capture_output=True)
    assert (result.returncode == 0) == expected, result.stdout + result.stderr
    return result

notice = {"_TRANSPORT": "kernel", "SYSLOG_IDENTIFIER": "kernel", "PRIORITY": "2",
          "MESSAGE": "Warning: Unmaintained driver is detected: nft_compat"}
assert "documented_compatibility_warnings=0" in run([], True).stdout
allowed = [dict(notice, MESSAGE="Warning: Unmaintained driver is detected: " + name)
           for name in ("nft_compat", "nft_compat_module_init", "ip_set", "ip_set_init")]
assert "documented_compatibility_warnings=4" in run(allowed, True).stdout
for overrides in ({"_TRANSPORT": "syslog"}, {"SYSLOG_IDENTIFIER": "dockerd"},
                  {"PRIORITY": "0"}, {"PRIORITY": "1"},
                  {"MESSAGE": notice["MESSAGE"] + " fatal"},
                  {"MESSAGE": "Warning: Unmaintained driver is detected: other"},
                  {"MESSAGE": "Kernel panic"}, {"MESSAGE": None}):
    run([dict(notice, **overrides)], False)
run([notice, dict(notice, MESSAGE="unrelated critical failure")], False)
run([], False, raw="invalid JSON\n")
run([], False, raw="[]\n")
print("Rocky journal classification: PASS (exact notices recorded; errors/spoofs rejected)")
