#!/usr/bin/env python3
"""Harden Sunshine's local administration and disable automatic router port mappings."""
import argparse
import os
from pathlib import Path
import re
import tempfile

REQUIRED = {"origin_web_ui_allowed": "pc", "upnp": "off"}
KEY = re.compile(r"^\s*(origin_web_ui_allowed|upnp)\s*=", re.IGNORECASE)


def validate_target(path: Path) -> None:
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError("refusing a non-regular Sunshine configuration")
    if path.parent.is_symlink():
        raise ValueError("refusing a symlinked Sunshine configuration directory")


def settings(data: str):
    values = {}
    for line in data.splitlines():
        if line.lstrip().startswith(("#", ";")):
            continue
        match = KEY.match(line)
        if match:
            key = match.group(1).lower()
            if key in values:
                return None
            values[key] = line.split("=", 1)[1].strip().split("#", 1)[0].strip().lower()
    return values


def accepted(data: str) -> bool:
    return settings(data) == REQUIRED


def harden(data: str) -> str:
    lines = [line for line in data.splitlines(keepends=True)
             if not (KEY.match(line) and not line.lstrip().startswith(("#", ";")))]
    return "".join(lines).rstrip("\n") + "\n" + "".join(
        f"{key} = {value}\n" for key, value in REQUIRED.items()
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    try:
        validate_target(args.path)
        if args.check:
            return 0 if args.path.is_file() and accepted(args.path.read_text(encoding="utf-8")) else 1
        args.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        before = args.path.read_text(encoding="utf-8") if args.path.exists() else ""
        if accepted(before):
            return 0
        tmp = None
        try:
            with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=args.path.parent,
                                             prefix=".sunshine-", delete=False) as handle:
                tmp = handle.name
                os.fchmod(handle.fileno(), 0o600)
                handle.write(harden(before))
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, args.path)
        finally:
            if tmp and os.path.exists(tmp):
                os.unlink(tmp)
    except (OSError, ValueError) as error:
        parser.exit(2, str(error) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
