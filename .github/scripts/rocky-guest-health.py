#!/usr/bin/env python3
"""Classify EL10 Docker compatibility notices; every other critical entry fails."""
import json
import sys

# Native EL10 kernel notices emitted by Docker's current stable iptables backend.
# Exact text and journal origin are required; no broad warning/error filtering.
NOTICES = {
    "Warning: Unmaintained driver is detected: " + name
    for name in ("nft_compat", "nft_compat_module_init", "ip_set", "ip_set_init")
}
warnings = []
errors = []
try:
    for line in sys.stdin:
        entry = json.loads(line)
        if not isinstance(entry, dict):
            raise ValueError("journal entry must be an object")
        if (entry.get("_TRANSPORT") == "kernel"
                and entry.get("SYSLOG_IDENTIFIER") == "kernel"
                and entry.get("PRIORITY") == "2"
                and entry.get("MESSAGE") in NOTICES):
            warnings.append(entry["MESSAGE"])
        else:
            errors.append(entry)
except (ValueError, TypeError) as exc:
    print(f"FAIL invalid critical journal: {exc}", file=sys.stderr)
    sys.exit(1)
for warning in warnings:
    print(f"WARN EL10 Docker compatibility: {warning}")
for entry in errors:
    print("FAIL critical journal: " + json.dumps(entry, ensure_ascii=False))
print(f"critical_journal: errors={len(errors)} documented_compatibility_warnings={len(warnings)}")
sys.exit(bool(errors))
