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

    def require_once(anchor: str) -> None:
        if code.count(anchor) != 1:
            raise ValueError(f"upstream Gtk4-DING v145 changed; fix needs review: {anchor[:80]!r}")

    def replace_once(old: str, new: str) -> None:
        nonlocal code
        require_once(old)
        code = code.replace(old, new, 1)

    # The reviewed GNOME 51 v145 ZIP already implements isEnabled and clears
    # it at disable(). Do not insert duplicate fields. Assert the exact
    # lifecycle shape from the Gtk4-100.29 release tag (not later main).
    require_once("    _init() {\n        this.isEnabled = false;")
    require_once("    disable() {\n        this.isEnabled = false;")

    # Set the flag before _activateDelayedLaunch() can run synchronously;
    # previously the flag became true only after this callback returned.
    replace_once(
        "        if (!this.settings)\n            this.settings = this._getSettings();\n\n        if (!this.killingProcess)",
        "        if (!this.settings)\n            this.settings = this._getSettings();\n\n        this.isEnabled = true;\n        if (!this.killingProcess)",
    )
    replace_once(
        "        this.isEnabled = true;\n\n        if (this.launchDesktop)",
        "        if (this.launchDesktop)",
    )
    replace_once(
        "    _activateDelayedLaunch() {\n        if (this.killingProcess) {",
        "    _activateDelayedLaunch() {\n        if (!this.isEnabled)\n            return;\n        if (this.killingProcess) {",
    )
    # The release tag had a startup-complete handler spelling mismatch.
    replace_once(
        "            this.startupPrepareId = null;\n            this._activateDelayedLaunch();",
        "            this.startupPreparedId = null;\n            this._activateDelayedLaunch();",
    )
    replace_once(
        "        if (this.startupPrepareId) {\n            Main.layoutManager.disconnect(this.startupPreparedId);",
        "        if (this.startupPreparedId) {\n            Main.layoutManager.disconnect(this.startupPreparedId);",
    )

    # Old child completions must not invalidate a newer Wayland client; most
    # importantly, neither a queued GLib timeout nor an asynchronous callback
    # may start a new process after the shell begins disabling the extension.
    replace_once(
        "    _doRelaunch(reloadTime) {\n        this.waylandClient = null;",
        "    _doRelaunch(reloadTime, client) {\n"
        "        if (!this.isEnabled || !client || this.waylandClient !== client)\n"
        "            return;\n"
        "        this.waylandClient = null;",
    )
    replace_once(
        "                        this.launchDesktop = 0;\n"
        "                        this._launchDesktop().catch(e => console.error(e));",
        "                        this.launchDesktop = 0;\n"
        "                        if (this.isEnabled)\n"
        "                            this._launchDesktop().catch(e => console.error(e));",
    )
    replace_once(
        "    async _launchDesktop() {\n        console.log('Launching Adw-DING process');",
        "    async _launchDesktop() {\n"
        "        if (!this.isEnabled)\n            return;\n"
        "        console.log('Launching Adw-DING process');",
    )
    replace_once(
        "        this.waylandClient = new LaunchSubprocess(0, 'Adw-DING');\n"
        "        this.waylandClient.set_cwd(GLib.get_home_dir());\n"
        "        this.windowTypeManager.set_wayland_client(this.waylandClient);",
        "        const client = new LaunchSubprocess(0, 'Adw-DING');\n"
        "        this.waylandClient = client;\n"
        "        client.set_cwd(GLib.get_home_dir());\n"
        "        this.windowTypeManager.set_wayland_client(client);",
    )
    replace_once(
        "            subprocess = await this.waylandClient.spawnv(argv);",
        "            subprocess = await client.spawnv(argv);",
    )
    replace_once(
        "        } catch (e) {\n            if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED)) {",
        "        } catch (e) {\n"
        "            if (this.waylandClient !== client)\n                return;\n"
        "            if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED)) {",
    )
    replace_once("                this._doRelaunch(1000);",
                 "                this._doRelaunch(1000, client);")
    replace_once(
        "        if (!this.waylandClient ||\n"
        "            subprocess !== this.waylandClient.subprocess\n"
        "        )",
        "        if (this.waylandClient !== client ||\n"
        "            subprocess !== client.subprocess\n"
        "        )",
    )
    replace_once("        this._doRelaunch(reloadTime);",
                 "        this._doRelaunch(reloadTime, client);")
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
