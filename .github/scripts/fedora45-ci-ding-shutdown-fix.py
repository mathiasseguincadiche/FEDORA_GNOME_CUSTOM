#!/usr/bin/env python3
"""Fail-closed GNOME 51 Gtk4-DING shutdown race patch for disposable QEMU.

The reviewed EGO ZIP remains SHA256-pinned and immutable. Only dingManager.js
is modified in the isolated candidate lab. All byte-for-byte replacements are
checked; verification independently regenerates the expected patched bytes
from the reviewed ZIP. No production installer is patched or unblocked.
"""
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
UUID = "gtk4-ding@smedius.gitlab.com"


def patched_source(original: bytes) -> bytes:
    code = original.decode("utf-8")

    def replace_once(old: str, new: str) -> None:
        nonlocal code
        if code.count(old) != 1:
            raise ValueError(f"upstream Gtk4-DING changed; fix needs review: {old[:80]!r}")
        code = code.replace(old, new, 1)

    # Upstream's fix-mutter-crash experiment introduced isEnabled to prevent
    # restart when disable() races with an asynchronous child exit. The
    # version-145 candidate still re-spawns from a queued GLib callback even
    # while the shell/session is being torn down.
    replace_once(
        "    _init() {\n        this.launchDesktop = 0;",
        "    _init() {\n        this.isEnabled = false;\n        this.launchDesktop = 0;",
    )
    replace_once(
        "    enable() {\n        if (typeof Meta.is_wayland_compositor",
        "    enable() {\n        if (typeof Meta.is_wayland_compositor",
    )
    replace_once(
        "            return;\n        }\n\n        if (!this.settings)",
        "            return;\n        }\n\n        this.isEnabled = true;\n        if (!this.settings)",
    )
    replace_once(
        "    _activateDelayedLaunch() {\n        if (this.killingProcess) {",
        "    _activateDelayedLaunch() {\n        if (!this.isEnabled)\n            return;\n        if (this.killingProcess) {",
    )
    replace_once(
        "    disable() {\n        this.DesktopIconsUsableArea = null;",
        "    disable() {\n        this.isEnabled = false;\n        this.DesktopIconsUsableArea = null;",
    )
    replace_once(
        "    _doRelaunch(reloadTime, client) {\n        if (!client || this.waylandClient !== client)",
        "    _doRelaunch(reloadTime, client) {\n        if (!this.isEnabled || !client || this.waylandClient !== client)",
    )
    replace_once(
        "                    this.launchDesktop = 0;\n                    this._launchDesktop().catch(e => console.error(e));",
        "                    this.launchDesktop = 0;\n                    if (this.isEnabled)\n                        this._launchDesktop().catch(e => console.error(e));",
    )
    replace_once(
        "    async _launchDesktop() {\n        console.log('Launching Adw-DING process');",
        "    async _launchDesktop() {\n        if (!this.isEnabled)\n            return;\n        console.log('Launching Adw-DING process');",
    )
    return code.encode("utf-8")


def run(operation: str) -> None:
    if operation not in {"apply", "verify"}:
        raise SystemExit("Usage: fedora45-ci-ding-shutdown-fix.py apply|verify")
    if ROOT != Path("/opt/fgc-lab/repo") or os.geteuid() == 0:
        raise SystemExit("Candidate patch is restricted to non-root disposable VM")
    if (subprocess.check_output(["id", "-un"], text=True).strip() != "lab"
            or subprocess.check_output(["hostname"], text=True).strip() != "fgc-fedora-ci"
            or subprocess.check_output(["systemd-detect-virt"], text=True).strip() not in ("qemu", "kvm")
            or not Path("/etc/fgc-ci-lab").is_file()
            or not re.search(r'^VERSION_ID="?45"?$', Path("/etc/os-release").read_text(), re.M)):
        raise SystemExit("Candidate patch refused outside Fedora 45 QEMU laboratory")

    spec = importlib.util.spec_from_file_location(
        "fgc_profile", ROOT / "scripts/development/fedora-profile.py"
    )
    profile_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(profile_module)
    profile = profile_module.assignments(ROOT / "profiles/fedora45/gnome-extensions.lock")
    if profile["DING_UUID"] != UUID or profile["DING_SHELL_VERSION"] != "51":
        raise SystemExit("Unreviewed Gtk4-DING role")
    archive = Path("/opt/fgc-lab/extensions/DING.zip")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != profile["DING_SHA256"]:
        raise SystemExit("Gtk4-DING reviewed ZIP checksum mismatch")
    with zipfile.ZipFile(archive) as z:
        original = z.read("dingManager.js")
    expected = patched_source(original)
    directory = Path.home() / ".local/share/gnome-shell/extensions" / UUID
    manager = directory / "dingManager.js"
    if manager.is_symlink() or not manager.is_file():
        raise SystemExit("Untrusted candidate manager path")
    current = manager.read_bytes()
    if operation == "apply":
        if current != original:
            raise SystemExit("Gtk4-DING installed source diverges from reviewed ZIP")
        manager.write_bytes(expected)
        current = manager.read_bytes()
    if current != expected:
        raise SystemExit("Gtk4-DING startup/shutdown fix missing or altered")
    digest = hashlib.sha256(expected).hexdigest()
    print(f"PASS: Gtk4-DING fail-closed relaunch guard ({operation}, sha256={digest})")


if __name__ == "__main__":
    try:
        run(sys.argv[1] if len(sys.argv) == 2 else "")
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error))
