#!/usr/bin/env python3
"""Portable observations from a native Live USB; never an installed-system certificate."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


def catalog_items(text):
    result = {}
    for line in text.splitlines():
        identifier, requirement, evidence = line.split("\t")
        if identifier in result or requirement not in ("required", "optional"):
            raise ValueError("Invalid Live check catalog")
        result[identifier] = (requirement, evidence)
    if not result:
        raise ValueError("Empty Live check catalog")
    return result


def checked_results(checks, catalog):
    seen = set()
    for item in checks:
        if not isinstance(item, dict) or set(item) != {"id", "status", "detail"}:
            raise ValueError("Invalid Live check result")
        identifier, status = item["id"], item["status"]
        if identifier not in catalog or identifier in seen:
            raise ValueError("Unknown or duplicated Live check")
        if status not in ("PASS", "FAIL", "NOT_TESTED") or not isinstance(item["detail"], str):
            raise ValueError("Invalid Live result status")
        seen.add(identifier)
        if status == "FAIL" or (catalog[identifier][0] == "required" and status != "PASS"):
            raise ValueError(f"Live check is not ready: {identifier}={status}")
    if seen != set(catalog):
        raise ValueError("Live report is incomplete")
    return checks


def parse_report(text, catalog):
    checks = []
    header = False
    schema_seen = False
    for line in text.splitlines():
        fields = line.split("\t", 2)
        if fields == ["STATUS", "CHECK", "DETAIL"]:
            header = True
        elif fields[0] == "SCHEMA":
            if fields != ["SCHEMA", "fgc-live-preflight", "2"]:
                raise ValueError("Unsupported Live report schema")
            schema_seen = True
        elif fields[0] in ("SUMMARY", "OPTIONAL_SUMMARY", "DECISION"):
            continue
        elif len(fields) == 3:
            status, identifier, detail = fields
            checks.append({"id": identifier, "status": status, "detail": detail})
        else:
            raise ValueError("Malformed Live TSV report")
    if not header or not schema_seen:
        raise ValueError("Live report header or schema is missing")
    return checked_results(checks, catalog)


def read_text(path):
    return path.read_text().strip()


def hardware_identity(sysroot=Path("/sys"), cpuinfo=Path("/proc/cpuinfo"), disks=None):
    """Stable identities only: no root UUID, kernel, user name or GPU card index."""
    if disks is None:
        disks = json.loads(subprocess.check_output(
            ["lsblk", "--json", "--nodeps", "-o", "NAME,TYPE,TRAN,MODEL,SERIAL"], text=True))["blockdevices"]
    nvme = sorted(({"model": str(d.get("model") or "").strip(),
                    "serial": str(d.get("serial") or "").strip()}
                   for d in disks if d.get("type") == "disk" and d.get("tran") == "nvme"
                   and "T705" in str(d.get("model") or "")), key=lambda d: d["serial"])
    if len(nvme) != 2 or any(not d["serial"] for d in nvme) or nvme[0]["serial"] == nvme[1]["serial"]:
        raise ValueError("Two distinct T705 serial numbers are required for the Live record")
    gpu = []
    for card in (sysroot / "class/drm").glob("card*"):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        device = card / "device"
        if (device / "vendor").is_file() and (device / "device").is_file():
            identity = (read_text(device / "vendor").lower(), read_text(device / "device").lower())
            if identity == ("0x8086", "0xe20b"):
                gpu.append(identity)
    if not gpu:
        raise ValueError("B580 identity is unavailable")
    cpu = {}
    for line in cpuinfo.read_text().split("\n\n", 1)[0].splitlines():
        key, separator, value = line.partition(":")
        if separator and key.strip() in ("vendor_id", "cpu family", "model", "stepping", "model name"):
            cpu[key.strip()] = value.strip()
    if not cpu:
        raise ValueError("CPU identity is unavailable")
    board = {key: read_text(sysroot / "class/dmi/id" / key) for key in ("board_vendor", "board_name")}
    return {"cpu": cpu, "board": board, "gpu": sorted(gpu), "nvme": nvme}


def digest_identity(identity):
    return hashlib.sha256(json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def verify(data, catalog, commit, module_plan, hardware):
    keys = {"schema", "gate", "verdict", "environment", "project_commit", "module_plan_sha256",
            "source_tree_clean", "hardware_certification", "hardware_fingerprint_sha256",
            "live_kernel", "checks", "created_utc"}
    if not isinstance(data, dict) or set(data) != keys:
        raise ValueError("Unexpected Live proof fields")
    expected = {"schema": 2, "gate": 2, "verdict": "PASS", "environment": "live-usb",
                "project_commit": commit, "module_plan_sha256": module_plan,
                "source_tree_clean": True, "hardware_certification": "PREINSTALL_ONLY",
                "hardware_fingerprint_sha256": hardware}
    for key, value in expected.items():
        if type(data[key]) is not type(value) or data[key] != value:
            raise ValueError(f"Live proof mismatch: {key}")
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or not all(
            re.fullmatch(r"[0-9a-f]{64}", value) for value in (module_plan, hardware)):
        raise ValueError("Invalid source or hardware identity")
    if not isinstance(data["live_kernel"], str) or not data["live_kernel"]:
        raise ValueError("Observed Live kernel is missing")
    datetime.strptime(data["created_utc"], "%Y-%m-%dT%H:%M:%SZ")
    if not isinstance(data["checks"], list):
        raise ValueError("Live checks must be an array")
    checked_results(data["checks"], catalog)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("hardware", "create", "verify"))
    parser.add_argument("--file", type=Path)
    parser.add_argument("--catalog")
    parser.add_argument("--commit")
    parser.add_argument("--module-plan")
    parser.add_argument("--hardware")
    parser.add_argument("--kernel")
    args = parser.parse_args()
    try:
        if args.action == "hardware":
            print(digest_identity(hardware_identity()))
            return
        catalog = catalog_items(args.catalog)
        if args.action == "create":
            data = {"schema": 2, "gate": 2, "verdict": "PASS", "environment": "live-usb",
                    "project_commit": args.commit, "module_plan_sha256": args.module_plan,
                    "source_tree_clean": True, "hardware_certification": "PREINSTALL_ONLY",
                    "hardware_fingerprint_sha256": args.hardware, "live_kernel": args.kernel,
                    "checks": parse_report(args.file.read_text(), catalog),
                    "created_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
            verify(data, catalog, args.commit, args.module_plan, args.hardware)
            print(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            verify(json.loads(args.file.read_text()), catalog, args.commit, args.module_plan, args.hardware)
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Live evidence: {error}\n")


if __name__ == "__main__":
    main()
