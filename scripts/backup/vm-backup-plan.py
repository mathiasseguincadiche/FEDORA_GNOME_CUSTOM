#!/usr/bin/env python3
"""Fail-closed inventory of persistent qcow2 disks, UEFI vars and emulated TPM state.

The VM XML is configuration input, not permission to back up arbitrary host files.
Check lexical paths and duplicate sources before the privileged backup runner acts.
The caller remains responsible for VM shutdown and source-file ownership/permissions.
"""
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

UUID_RE = re.compile(r"[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}")
DEVICE_RE = re.compile(r"[a-zA-Z0-9_-]+")
# Never let a libvirt XML reference pseudo-filesystems or operating-system
# secrets as a qcow2/NVRAM/TPM backup source.
DENIED_ROOTS = {"/dev", "/proc", "/sys", "/run", "/etc", "/root"}


def safe_source_path(raw: str, *, field: str) -> str:
    if not isinstance(raw, str) or not raw.startswith("/") or raw.startswith("//"):
        raise ValueError(f"{field}: absolute local path required")
    segments = raw.split("/")[1:]
    if not segments or any(segment in ("", ".", "..") for segment in segments):
        raise ValueError(f"{field}: noncanonical path or traversal")
    if any(ord(char) < 32 or ord(char) == 127 for char in raw):
        raise ValueError(f"{field}: control character in path")
    clean = str(pathlib.PurePosixPath(raw))
    if clean in DENIED_ROOTS or any(clean.startswith(root + "/") for root in DENIED_ROOTS):
        raise ValueError(f"{field}: host-system path forbidden")
    return clean


def plan(xml: str) -> dict:
    root = ET.fromstring(xml)
    uuid = root.findtext("uuid", "")
    if not UUID_RE.fullmatch(uuid):
        raise ValueError("Missing or invalid domain UUID")

    disks = []
    occupied = set()
    targets = set()
    for disk in root.findall("./devices/disk"):
        if disk.get("device") != "disk":
            continue
        source, driver, target = disk.find("source"), disk.find("driver"), disk.find("target")
        if (disk.get("type") != "file" or source is None or driver is None
                or driver.get("type") != "qcow2" or target is None):
            raise ValueError("VM backup supports file-backed qcow2 disks only; unsupported disk is not skipped")
        path = safe_source_path(source.get("file", ""), field="VM disk")
        dev = target.get("dev", "")
        if not DEVICE_RE.fullmatch(dev):
            raise ValueError("Invalid VM disk target")
        if path in occupied or dev in targets:
            raise ValueError("Duplicate VM disk source or target")
        occupied.add(path)
        targets.add(dev)
        disks.append({"source": path, "target": dev})

    states = []
    nvram = root.find("./os/nvram")
    if nvram is not None:
        source = nvram.find("source")
        raw = (nvram.text or "").strip() or (source.get("file", "") if source is not None else "")
        states.append(safe_source_path(raw, field="NVRAM"))

    for tpm in root.findall("./devices/tpm/backend"):
        if tpm.get("type") != "emulator" or tpm.find("encryption") is not None:
            raise ValueError("Unsupported TPM backend or encrypted TPM secret: explicit recovery procedure required")
        source = tpm.find("source")
        raw = source.get("path", "") if source is not None else f"/var/lib/libvirt/swtpm/{uuid}"
        states.append(safe_source_path(raw, field="TPM state"))

    for path in states:
        if path in occupied:
            raise ValueError("VM disk and persistent state paths overlap")
        occupied.add(path)
    if not disks:
        raise ValueError("No persistent VM disk found")
    if len(set(states)) != len(states):
        raise ValueError("Duplicate VM persistent state paths")
    return {"uuid": uuid, "disks": disks, "state_paths": states}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: vm-backup-plan.py LIBVIRT_DOMAIN.xml")
    try:
        print(json.dumps(plan(pathlib.Path(sys.argv[1]).read_text()), indent=2))
    except (ValueError, OSError, ET.ParseError) as error:
        sys.exit(str(error))
