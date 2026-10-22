#!/usr/bin/env python3
"""Reviewed Gtk4-DING v145 shutdown fix shared by installer and laboratory.

The downloaded upstream ZIP stays immutable and SHA256-pinned. Only the exact
reviewed dingManager.js is transformed; the installed result has its own digest.
Revisit this patch when the upstream lifecycle and client ownership guards land.
"""
import hashlib
from pathlib import Path
import sys
import zipfile

ARCHIVE_SHA256 = "4a884fa3976aeb814726fd96428c09cfeca2da01aec3ac8629ddd6cd22bff2c1"
MANAGER_SHA256 = "09a128df98fec26550e9dd259b6dd712cd7bb3e0da059f1e82ee5befc623447f"


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


def verify(directory):
    manager = Path(directory) / "dingManager.js"
    if Path(directory).is_symlink() or manager.is_symlink() or not manager.is_file():
        raise ValueError("Unsafe Gtk4-DING installed path")
    if hashlib.sha256(manager.read_bytes()).hexdigest() != MANAGER_SHA256:
        raise ValueError("Gtk4-DING shutdown fix missing or modified")


def apply(archive, directory):
    archive = Path(archive)
    manager = Path(directory) / "dingManager.js"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Unreviewed Gtk4-DING archive")
    with zipfile.ZipFile(archive) as source:
        original = source.read("dingManager.js")
    expected = patched_source(original)
    if hashlib.sha256(expected).hexdigest() != MANAGER_SHA256:
        raise ValueError("Reviewed patch result changed; explicit review required")
    if Path(directory).is_symlink() or manager.is_symlink() or manager.read_bytes() != original:
        raise ValueError("Installed Gtk4-DING diverges from reviewed upstream source")
    manager.write_bytes(expected)
    verify(directory)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "apply":
            apply(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 3 and sys.argv[1] == "verify":
            verify(sys.argv[2])
        else:
            raise ValueError("Usage: ding-shutdown-fix.py apply ARCHIVE DIRECTORY | verify DIRECTORY")
        print("PASS: reviewed Gtk4-DING shutdown guard sha256=" + MANAGER_SHA256)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error))
