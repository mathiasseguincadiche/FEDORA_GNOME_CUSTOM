#!/usr/bin/env python3
"""Enforce Sunshine localhost-only web administration without changing other settings."""
import argparse
import os
from pathlib import Path
import re
import tempfile

KEY = re.compile(r"^\s*origin_web_ui_allowed\s*=", re.IGNORECASE)

def accepted(data: str) -> bool:
    values = [line.split("=", 1)[1].strip() for line in data.splitlines()
              if KEY.match(line) and not line.lstrip().startswith(("#", ";"))]
    return values == ["pc"]

def harden(data: str) -> str:
    lines = [line for line in data.splitlines(keepends=True) if
             not (KEY.match(line) and not line.lstrip().startswith(("#", ";")))]
    return "".join(lines).rstrip("\n") + "\norigin_web_ui_allowed = pc\n"

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true")
    p.add_argument("path", type=Path)
    a = p.parse_args()
    if a.check:
        return 0 if a.path.is_file() and accepted(a.path.read_text()) else 1
    a.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    before = a.path.read_text() if a.path.exists() else ""
    if accepted(before):
        return 0
    tmp = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=a.path.parent,
                                         prefix=".sunshine-", delete=False) as h:
            tmp = h.name
            os.fchmod(h.fileno(), 0o600)
            h.write(harden(before))
            h.flush()
            os.fsync(h.fileno())
        os.replace(tmp, a.path)
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
