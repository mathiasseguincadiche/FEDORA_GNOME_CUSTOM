#!/usr/bin/env python3
"""Offline lifecycle regression of the reviewed GNOME 51 Gtk4-DING candidate patch."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "ding_shutdown_fix", root / ".github/scripts/fedora45-ci-ding-shutdown-fix.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# Exact upstream anchor shapes (GNOME Shell 51 reviewed candidate v145), with
# minimal artificial context. Byte-exact archive comparison runs in real QEMU.
source = """
const DingManager = class {
    _init() {
        this.launchDesktop = 0;
    }
    enable() {
        if (typeof Meta.is_wayland_compositor === 'function' &&
            !Meta.is_wayland_compositor()
        ) {
            console.error('Wayland required');
            return;
        }

        if (!this.settings)
            this.settings = this._getSettings();
    }
    _activateDelayedLaunch() {
        if (this.killingProcess) {
            return;
        }
    }
    disable() {
        this.DesktopIconsUsableArea = null;
    }
    _doRelaunch(reloadTime, client) {
        if (!client || this.waylandClient !== client)
            return;
        this.launchDesktop =
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, reloadTime, () => {
                    this.launchDesktop = 0;
                    this._launchDesktop().catch(e => console.error(e));
                    return false;
            });
    }
    async _launchDesktop() {
        console.log('Launching Adw-DING process');
    }
};
"""
result = module.patched_source(source.encode("utf-8")).decode("utf-8")
assert "this.isEnabled = false;\n        this.launchDesktop = 0;" in result
assert "this.isEnabled = true;\n        if (!this.settings)" in result
assert "disable() {\n        this.isEnabled = false;" in result
assert "_activateDelayedLaunch() {\n        if (!this.isEnabled)" in result
assert "if (!this.isEnabled || !client || this.waylandClient !== client)" in result
assert "if (this.isEnabled)\n                        this._launchDesktop()" in result
assert "async _launchDesktop() {\n        if (!this.isEnabled)" in result

for damaged in (
    source.replace("if (!client || this.waylandClient !== client)", "if (true)"),
    source.replace("console.log('Launching Adw-DING process');", ""),
    source.replace("this.launchDesktop = 0;", "this.launchDesktop = 0;\n        this.launchDesktop = 0;", 1),
):
    try:
        module.patched_source(damaged.encode("utf-8"))
    except ValueError:
        pass
    else:
        raise AssertionError("Unreviewed source change was accepted")

try:
    module.patched_source(result.encode("utf-8"))
except ValueError:
    pass
else:
    raise AssertionError("Applying the patch twice must be rejected")

print("GNOME 51 Gtk4-DING shutdown guard transformation: PASS")
