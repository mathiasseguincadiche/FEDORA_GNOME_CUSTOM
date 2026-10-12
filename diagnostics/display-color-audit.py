#!/usr/bin/env python3
"""Read-only, privacy-conscious DRM connector inventory.

This is a triage tool, NOT a color calibration tool or Gate 3 certificate.
sysfs "modes" lists supported modes, not the active GNOME/Wayland mode.
Never read EDID bytes/monitor serials, modify modes, or invoke privileged tools.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def _one_line(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, UnicodeError, IndexError):
        return None


def audit_connectors(root: Path) -> dict:
    """Only report observable sysfs facts; never infer Full RGB, HDR or VRR."""
    connectors: list[dict] = []
    if root.is_dir():
        for item in sorted(root.glob("card*-*")):
            if not item.is_dir() or not (item / "status").is_file():
                continue
            state = _one_line(item / "status")
            if state not in {"connected", "disconnected", "unknown"}:
                state = "unknown"
            enabled = _one_line(item / "enabled")
            if enabled not in {"enabled", "disabled"}:
                enabled = "unknown"
            try:
                modes = (item / "modes").read_text(encoding="utf-8").splitlines()
            except (OSError, UnicodeError):
                modes = []
            # These are SUPPORTED modes only. Never call any of them "active".
            modes = [mode.strip() for mode in modes if mode.strip()][:12]
            connectors.append({
                "connector": item.name,
                "status": state,
                "enabled": enabled,
                "supported_modes_sample": modes,
            })
    return {
        "schema": 1,
        "operation": "read-only",
        "hardware_certification": "DEFERRED",
        "connector_inventory": "OBSERVED" if connectors else "NOT_TESTED",
        "connectors": connectors,
        "visual_and_color_checks": {
            "current_resolution_and_refresh": "NOT_TESTED",
            "rgb_range_full_vs_limited": "NOT_TESTED",
            "sdr_white_and_hdr_tone_mapping": "NOT_TESTED",
            "icc_profile_and_night_light": "NOT_TESTED",
            "vrr_and_suspend_resume": "NOT_TESTED",
        },
        "notes": [
            "The modes exposed by sysfs are supported, not necessarily active.",
            "No EDID bytes, serial numbers, screenshots, IP or MAC addresses are collected.",
            "Use gdctl and the monitor OSD, then compare with human visual inspection.",
            "No automatic color/HDR/VRR settings or GPU overrides are applied.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sysfs-root", type=Path, default=Path("/sys/class/drm"),
                        help="DRM class directory; override is for isolated tests only")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args()
    report = audit_connectors(args.sysfs_root)
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print("DRM display inventory — read-only; Gate 3 NOT certified")
        for monitor in report["connectors"]:
            modes = ", ".join(monitor["supported_modes_sample"][:4]) or "unknown"
            print(f"- {monitor['connector']}: {monitor['status']}, "
                  f"{monitor['enabled']}; supported modes: {modes}")
        if not report["connectors"]:
            print("- No readable DRM connector data: NOT_TESTED")
        print("RGB full/limited, HDR/SDR, ICC, active 240 Hz and visual white: NOT_TESTED")
        print("Review GNOME Display settings, gdctl, monitor OSD and a physical A/B check.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
