#!/usr/bin/env python3
"""CI pretest evidence: no official validation-gate proof is written."""
import argparse
import json
import pathlib
import re

REQUIRED = ("image", "boot", "gnome", "reboot", "borg_files", "cold_archive",
            "restored_vm", "rebuilt_os")
DEFERRED = ("gate1_wsl2", "gate2_visual", "gate3_hardware",
            "production_apply", "windows_vm", "upstream_kernel_boot")


def initialize(commit):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("exact Git commit required")
    return dict(schema=1, scope="fedora-gnome-qemu-pretest", commit=commit,
                verdict="PENDING", checks={k: "PENDING" for k in REQUIRED},
                deferred={k: "DEFERRED" for k in DEFERRED}, evidence={})


def finalize(report):
    if report["checks"] != {k: "PASS" for k in REQUIRED}:
        raise ValueError("all exercises must pass")
    e = report["evidence"]
    ids = [e[k] for k in ("boot_id", "reboot_id", "restored_boot_id", "rebuilt_boot_id")]
    if any(not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", x) for x in ids) or len(set(ids)) != 4:
        raise ValueError("four distinct kernel boot identities required")
    for key in ("files_archive_id", "cold_archive_id", "disk_sha256", "nvram_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", e[key]):
            raise ValueError("archive/disk identity missing: " + key)
    if e["recovery_network"] != "restrict=on" or e["encryption"] != "none":
        raise ValueError("isolated recovery and unencrypted Borg required")
    if e["session_shutdown"] != "gnome-logout":
        raise ValueError("qualified orderly GNOME shutdown required")
    if e["tpm_canary"] != "PASS":
        raise ValueError("TPM persistent canary required")
    if report["deferred"] != {k: "DEFERRED" for k in DEFERRED}:
        raise ValueError("CI cannot certify official gates")
    if not re.fullmatch(r"[0-9a-f]{40}", report["commit"]):
        raise ValueError("invalid commit")
    report["verdict"] = "PASS"
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=pathlib.Path)
    parser.add_argument("action", choices=("init", "pass", "evidence", "finalize", "fail"))
    parser.add_argument("key", nargs="?")
    parser.add_argument("value", nargs="?")
    a = parser.parse_args()
    r = initialize(a.key) if a.action == "init" else json.loads(a.path.read_text())
    if a.action == "pass":
        if a.key not in REQUIRED:
            raise ValueError("unknown exercise")
        r["checks"][a.key] = "PASS"
    elif a.action == "evidence":
        r["evidence"][a.key] = a.value
    elif a.action == "finalize":
        r = finalize(r)
    elif a.action == "fail":
        r["verdict"] = "FAIL"
    temporary = a.path.with_suffix(".tmp")
    temporary.write_text(json.dumps(r, indent=2) + "\n")
    temporary.replace(a.path)


if __name__ == "__main__":
    main()
