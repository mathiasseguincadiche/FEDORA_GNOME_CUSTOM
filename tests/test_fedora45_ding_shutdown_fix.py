#!/usr/bin/env python3
"""Regress real Gtk4-DING 100.29 (EGO v145) shutdown-race source structure."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "ding_shutdown_fix", root / ".github/scripts/fedora45-ci-ding-shutdown-fix.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# A compact set of exact release-tag anchors, rather than later GitLab main.
# The real QEMU job also verifies archive SHA and compares every patched byte.
source = """
    _init() {
        this.isEnabled = false;
        this.launchDesktop = 0;
    }
    enable() {
        if (!this.settings)
            this.settings = this._getSettings();

        if (!this.killingProcess)
            return;
        this.isEnabled = true;

        if (this.launchDesktop)
            GLib.source_remove(this.launchDesktop);
    }
        else {
            this.startupPrepareId = null;
            this._activateDelayedLaunch();
        }
    _activateDelayedLaunch() {
        if (this.killingProcess) {
            return;
        }
        if (this.startupPrepareId) {
            Main.layoutManager.disconnect(this.startupPreparedId);
        }
    }
    disable() {
        this.isEnabled = false;
        this.DesktopIconsUsableArea = null;
    }
    _doRelaunch(reloadTime) {
        this.waylandClient = null;
        if (this.isEnabled) {
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, reloadTime,
                () => {
                        this.launchDesktop = 0;
                        this._launchDesktop().catch(e => console.error(e));
                });
        }
    }
    async _launchDesktop() {
        console.log('Launching Adw-DING process');
        this.waylandClient = new LaunchSubprocess(0, 'Adw-DING');
        this.waylandClient.set_cwd(GLib.get_home_dir());
        this.windowTypeManager.set_wayland_client(this.waylandClient);
        try {
            subprocess = await this.waylandClient.spawnv(argv);
        } catch (e) {
            if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED)) {
                this._doRelaunch(1000);
            }
            return;
        }
        if (!this.waylandClient ||
            subprocess !== this.waylandClient.subprocess
        )
            return;
        this._doRelaunch(reloadTime);
    }
"""
result = module.patched_source(source.encode()).decode()
assert "    _init() {\n        this.isEnabled = false;" in result
assert "    disable() {\n        this.isEnabled = false;" in result
assert "        this.isEnabled = true;\n        if (!this.killingProcess)" in result
assert result.count("this.isEnabled = true;") == 1
assert "    _activateDelayedLaunch() {\n        if (!this.isEnabled)\n            return;" in result
assert "this.startupPrepareId" not in result
assert "    _doRelaunch(reloadTime, client) {\n        if (!this.isEnabled || !client || this.waylandClient !== client)" in result
assert "                        if (this.isEnabled)\n                            this._launchDesktop()" in result
assert "    async _launchDesktop() {\n        if (!this.isEnabled)\n            return;" in result
assert "        const client = new LaunchSubprocess(0, 'Adw-DING');" in result
assert "            subprocess = await client.spawnv(argv);" in result
assert "        this._doRelaunch(reloadTime, client);" in result

# Every edited upstream anchor remains unique and mandatory.
for damaged in (
    source.replace("    _init() {\n        this.isEnabled = false;",
                   "    _init() {\n        this.isEnabled = true;"),
    source.replace("    disable() {\n        this.isEnabled = false;",
                   "    disable() {\n        this.isEnabled = true;"),
    source.replace("this.startupPrepareId = null;",
                   "this.startupPreparedId = null;"),
    source.replace("this._doRelaunch(reloadTime);", "this._doRelaunch(reloadTime, client);"),
    source.replace("        const NOT_PRESENT", "never-match")
        + "\n    _init() {\n        this.isEnabled = false;",
):
    try:
        module.patched_source(damaged.encode())
    except ValueError:
        pass
    else:
        raise AssertionError("Unreviewed/repeated release source anchor accepted")

try:
    module.patched_source(result.encode())
except ValueError:
    pass
else:
    raise AssertionError("Double-patching the reviewed candidate must fail")

print("Gtk4-DING v145 shutdown/relaunch guard: PASS")
