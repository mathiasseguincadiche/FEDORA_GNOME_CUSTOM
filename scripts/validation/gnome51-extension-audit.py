#!/usr/bin/env python3
"""Read-only GNOME 51 six-role extension audit; never installs or enables anything.

--report summarizes candidates and the release gate, never claiming a runtime PASS.
--live requires a promoted and digest-verified Fedora 45 profile, then checks the
running Wayland GNOME 51 session and actual six active extension identities.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROLE_UUIDS = {
    "dash": "dash-to-dock@micxgx.gmail.com",
    "appindicator": "appindicatorsupport@rgcjonas.gmail.com",
}
LOCK_ROLES = {
    "desktop_icons": "DING",
    "show_desktop": "SHOW_DESKTOP_PLUS",
    "telemetry": "RESOURCE_MONITOR",
    "tiling": "TILING_ASSISTANT",
}
DISALLOWED = {"just-perfection-desktop@just-perfection", "dash-to-panel@jderose9.github.com"}


def load_profile_module(root: Path):
    path = root / "scripts/development/fedora-profile.py"
    spec = importlib.util.spec_from_file_location("fgc_fedora_profile", path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def selected_roles(root: Path) -> dict[str, str]:
    lock = load_profile_module(root).assignments(root / "profiles/fedora45/gnome-extensions.lock")
    roles = dict(ROLE_UUIDS)
    for role, key in LOCK_ROLES.items():
        uid = lock.get(key + "_UUID", "")
        if not re.fullmatch(r"[A-Za-z0-9_@.+-]{3,128}", uid):
            raise ValueError(f"invalid UUID for {role}")
        if lock.get(key + "_SHELL_VERSION") != "51":
            raise ValueError(f"unported GNOME role: {role}")
        if not re.fullmatch(r"[0-9a-f]{64}", lock.get(key + "_SHA256", "")):
            raise ValueError(f"missing pinned extension digest: {role}")
        roles[role] = uid
    if len(set(roles.values())) != len(roles):
        raise ValueError("GNOME roles must be distinct extensions")
    return roles


def assess(roles: dict[str, str], active: set[str], enabled: set[str],
           metadata: dict[str, dict], provenance: dict[str, str], lock: dict[str, str]) -> dict:
    """Pure evaluator: fake states cannot be interpreted as GNOME runtime proof."""
    entries = {}
    for role, uuid in roles.items():
        info = metadata.get(uuid, {})
        versions = info.get("shell-version", [])
        compatible = isinstance(versions, list) and any(str(v).split(".")[0] == "51" for v in versions)
        exact_id = info.get("uuid") == uuid
        source_ok = True
        if role in LOCK_ROLES:
            source_ok = provenance.get(uuid) == lock[LOCK_ROLES[role] + "_SHA256"]
        entries[role] = {
            "uuid": uuid,
            "active": uuid in active,
            "enabled": uuid in enabled,
            "metadata_51": compatible and exact_id,
            "reviewed_sha": source_ok,
            "verdict": "PASS" if uuid in active and uuid in enabled and compatible and exact_id and source_ok else "FAIL",
        }
    unexpected = sorted(active.intersection(DISALLOWED))
    return {
        "schema": 1,
        "profile": "fedora45-gnome51",
        "verdict": "PASS" if all(x["verdict"] == "PASS" for x in entries.values()) and not unexpected else "FAIL",
        "roles": entries,
        "forbidden_active": unexpected,
        "hardware_gate3": "DEFERRED",
    }


def run(*args: str) -> str:
    return subprocess.run(args, capture_output=True, text=True, check=True, timeout=20).stdout


def live_report(root: Path, profile: dict, roles: dict[str, str]) -> dict:
    if profile.get("status") != "ready":
        raise ValueError("Fedora 45 profile pending: GNOME 51 runtime cannot be certified")
    load_profile_module(root).validate(root, 45)
    if os.geteuid() == 0:
        raise ValueError("GNOME runtime check must execute as the desktop user")
    if os.environ.get("XDG_SESSION_TYPE") != "wayland":
        raise ValueError("GNOME 51 Wayland session required")
    version = run("gnome-shell", "--version").strip()
    if not re.fullmatch(r"GNOME Shell 51(?:[.][0-9]+)*", version):
        raise ValueError(f"unexpected GNOME version: {version}")
    enabled = set(run("gnome-extensions", "list", "--enabled").splitlines())
    active = set(run("gnome-extensions", "list", "--active").splitlines())
    lock = load_profile_module(root).assignments(root / "profiles/fedora45/gnome-extensions.lock")
    user_base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "gnome-shell/extensions"
    system_base = Path("/usr/share/gnome-shell/extensions")
    metadata = {}
    provenance = {}
    for role, uuid in roles.items():
        candidate = user_base / uuid
        if role in ROLE_UUIDS:
            if candidate.exists():
                raise ValueError(f"unreviewed user override of RPM extension: {uuid}")
            candidate = system_base / uuid
        # A metadata/marker read is evidence, not an installation action.
        meta_path = candidate / "metadata.json"
        if not meta_path.is_file() or meta_path.is_symlink():
            continue
        metadata[uuid] = json.loads(meta_path.read_text(encoding="utf-8"))
        if role in LOCK_ROLES:
            marker = candidate / ".fedora-gnome-custom-source"
            if marker.is_file() and not marker.is_symlink():
                rows = marker.read_text(encoding="utf-8").splitlines()
                hashes = [row.removeprefix("sha256=") for row in rows if row.startswith("sha256=")]
                if len(hashes) == 1:
                    provenance[uuid] = hashes[0]
    return assess(roles, active, enabled, metadata, provenance, lock)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--report", action="store_true", help="candidate summary only; never a PASS")
    group.add_argument("--live", action="store_true", help="qualify real logged-in GNOME 51 user session")
    args = parser.parse_args(argv)
    try:
        profile = json.loads((args.root / "profiles/fedora45/profile.json").read_text())
        roles = selected_roles(args.root)
        if (profile.get("release"), profile.get("gnome_major")) != (45, 51):
            raise ValueError("wrong Fedora/GNOME release identity")
        if args.report:
            report = {"schema": 1, "verdict": "DEFERRED",
                      "profile_status": profile.get("status"), "expected_roles": roles,
                      "note": "This report does not certify extensions, GNOME runtime or hardware."}
        else:
            report = live_report(args.root, profile, roles)
    except (OSError, ValueError, json.JSONDecodeError, KeyError, subprocess.CalledProcessError,
            subprocess.TimeoutExpired) as error:
        report = {"schema": 1, "verdict": "FAIL", "reason": str(error), "hardware_gate3": "DEFERRED"}
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report["verdict"] in ("PASS", "DEFERRED") else 1


if __name__ == "__main__":
    raise SystemExit(main())
