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


def initialize(commit, release=44, extension_mode="curated"):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("exact Git commit required")
    if (release, extension_mode) not in ((44, "curated"), (45, "native")):
        raise ValueError("unsupported laboratory target")
    return dict(schema=2, release=release, gnome_major=release+6, extension_mode=extension_mode, scope="fedora-gnome-qemu-pretest", commit=commit,
                verdict="PENDING", checks={k: "PENDING" for k in REQUIRED},
                deferred={k: "DEFERRED" for k in DEFERRED}, evidence={})


def finalize(report):
    if report["checks"] != {k: "PASS" for k in REQUIRED}:
        raise ValueError("all exercises must pass")
    e = report["evidence"]
    target = (report["release"], report["extension_mode"])
    if target not in ((44, "curated"), (45, "native")) or report["gnome_major"] != report["release"] + 6:
        raise ValueError("invalid laboratory target")
    if (e.get("fedora_release"), e.get("gnome_major"), e.get("extension_mode")) != (str(report["release"]), str(report["gnome_major"]), report["extension_mode"]):
        raise ValueError("guest target evidence missing")
    expected_extensions = "six-active" if report["extension_mode"] == "curated" else "DEFERRED"
    if e.get("curated_extensions") != expected_extensions:
        raise ValueError("native preview cannot certify curated extensions")
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
    if a.action == "init":
        release, mode = (a.value or "44:curated").split(":")
        r = initialize(a.key, int(release), mode)
    else:
        r = json.loads(a.path.read_text())
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
