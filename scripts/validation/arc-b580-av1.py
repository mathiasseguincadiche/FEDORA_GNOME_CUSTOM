#!/usr/bin/env python3
"""Read-only Arc B580 AV1 VA-API preflight, not a Sunshine/Moonlight certification.

Never touches display settings, Sunshine configs, services, the network or GPU drivers.
Only reports actual VA-API capabilities from a DRM render node bound to xe/B580.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess


def parse_vainfo(output: str) -> dict[str, bool]:
    entries = set()
    for line in output.splitlines():
        match = re.search(r"\bVAProfileAV1Profile0\s*:\s*(VAEntrypoint[A-Za-z0-9_]+)", line)
        if match:
            entries.add(match.group(1))
    return {
        "av1_decode": "VAEntrypointVLD" in entries,
        "av1_encode": bool(entries & {"VAEntrypointEncSlice", "VAEntrypointEncSliceLP"}),
    }


def b580_render_nodes(sysfs_root: Path) -> list[str]:
    """Identify render nodes via PCI vendor/device AND active xe binding."""
    result = []
    for item in sorted(sysfs_root.glob("renderD*")):
        device = item / "device"
        try:
            vendor = (device / "vendor").read_text().strip().lower()
            identity = (device / "device").read_text().strip().lower()
            driver = (device / "driver").resolve(strict=True).name
        except (OSError, UnicodeError):
            continue
        if (vendor, identity, driver) == ("0x8086", "0xe20b", "xe"):
            result.append(item.name)
    return result


def inspect(sysfs_root: Path = Path("/sys/class/drm")) -> dict:
    nodes = b580_render_nodes(sysfs_root)
    report = {
        "schema": 1,
        "hardware_certification": "DEFERRED",
        "sunshine_moonlight_end_to_end": "NOT_TESTED",
        "tablet_av1_decode": "NOT_TESTED",
        "wifi7_and_wol": "NOT_TESTED",
        "status": "NOT_TESTED",
        "b580_xe_render_nodes": nodes,
        "av1_decode": False,
        "av1_encode": False,
    }
    # Multiple GPUs or render nodes: only accept capabilities reported on the
    # actual B580 PCI function. Never query a guessed renderD128 as proof.
    if len(nodes) != 1:
        report["reason"] = "Expected exactly one readable B580 render node bound to xe"
        return report
    try:
        proc = subprocess.run(
            ["vainfo", "--display", "drm", "--device", "/dev/dri/" + nodes[0]],
            capture_output=True, text=True, check=True, timeout=30)
        profiles = parse_vainfo(proc.stdout + "\n" + proc.stderr)
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        report["reason"] = "vainfo not usable for this GPU: " + type(error).__name__
        return report
    report.update(profiles)
    report["status"] = "CAPABILITY_OBSERVED" if all(profiles.values()) else "MISSING_AV1_CAPABILITY"
    report["reason"] = ("Encoder and decoder entrypoints are visible for this B580 render node; "
                        "the actual Sunshine encoder and tablet decoder are not tested")
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--require-av1", action="store_true", help="fail if B580 AV1 VA-API encode+decode not observed")
    args = parser.parse_args(argv)
    result = inspect()
    if args.format == "json":
        print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
    else:
        print(f"Intel Arc B580/xe AV1 capability: {result['status']}")
        print(f"Decode: {result['av1_decode']} | Encode: {result['av1_encode']}")
        print(f"Sunshine/Moonlight AV1 streaming: {result['sunshine_moonlight_end_to_end']}")
        print("The tablet, network, wake-up and actual video pipeline require physical Gate 3.")
        if "reason" in result:
            print(result["reason"])
    return 1 if args.require_av1 and result["status"] != "CAPABILITY_OBSERVED" else 0


if __name__ == "__main__":
    raise SystemExit(main())
