#!/usr/bin/env python3
"""Bounded read-only GNOME extension-list probe for the Fedora 45 QEMU audit.

Some GNOME 51 software-rendered VM sessions intermittently return non-zero
from the extension CLI after all six individual 'info' checks succeed. A
transient D-Bus query failure must not invalidate a real restore, but it must
also never be treated as proof of healthy extensions. Only a successful CLI
response supplies evidence; permanent errors and timeouts remain fatal.
"""
import subprocess
import sys
import time


def list_extensions(flag, *, attempts=5, interval=2, run=subprocess.run, sleep=time.sleep):
    """Require a successful GNOME Shell response; retry temporary CLI failures.

    Each query has a 20-second hard timeout. Both enabled and active sets are
    independently queried, then assessed by the existing strict six-role gate.
    """
    if flag not in ("--active", "--enabled"):
        raise ValueError("Unsupported GNOME extension-list probe")
    if not (1 <= attempts <= 5) or not (0 <= interval <= 5):
        raise ValueError("Unbounded GNOME extension-list retry parameters")

    command = ["gnome-extensions", "list", flag]
    detail = "no GNOME Shell response"
    for attempt in range(1, attempts + 1):
        try:
            completed = run(command, capture_output=True, text=True, timeout=20, check=False)
        except subprocess.TimeoutExpired:
            detail = "GNOME extension-list D-Bus request timed out (20s)"
        else:
            if completed.returncode == 0:
                return set(completed.stdout.splitlines())
            detail = (
                f"exit={completed.returncode}; "
                f"stderr={completed.stderr.strip()[:1200]!r}; "
                f"stdout={completed.stdout.strip()[:500]!r}"
            )
            # A broken or removed CLI option is deterministic, not a retryable
            # session-startup race. Do not waste attempts or hide that failure.
            if "Unknown option" in completed.stderr or "unknown option" in completed.stderr:
                raise RuntimeError(f"{' '.join(command)}: {detail}")
        if attempt < attempts:
            print(
                f"GNOME 51 candidate audit: {' '.join(command)} failed "
                f"({attempt}/{attempts}), retrying: {detail}",
                file=sys.stderr,
            )
            sleep(interval)
    raise RuntimeError(
        f"GNOME 51 candidate audit: {' '.join(command)} failed after "
        f"{attempts} attempts: {detail}"
    )
