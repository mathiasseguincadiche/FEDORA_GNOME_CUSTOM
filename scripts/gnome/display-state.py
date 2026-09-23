#!/usr/bin/env python3
"""Preserve the complete Mutter layout across one suspend/resume cycle.

D-Bus contract: GNOME/mutter data/dbus-interfaces/org.gnome.Mutter.DisplayConfig.xml.
Automatic restore is temporary and requires the same physical monitor identities.
"""
import json
import os
from pathlib import Path
import sys
import tempfile


def snapshot(state):
    _, monitors, logical, properties = state
    by_spec = {tuple(spec): (modes, props) for spec, modes, props in monitors}
    result = {'identities': sorted([list(spec) for spec in by_spec]), 'logical': [], 'properties': {}}
    if any(props.get('is-for-lease') for _, props in by_spec.values()):
        raise ValueError('Display leases are not supported by automatic recovery')
    if properties.get('supports-changing-layout-mode'):
        result['properties']['layout-mode'] = properties['layout-mode']
    for x, y, scale, transform, primary, specs, _ in logical:
        outputs = []
        for spec in specs:
            modes, props = by_spec[tuple(spec)]
            current = [mode for mode in modes if mode[6].get('is-current')]
            if len(current) != 1:
                raise ValueError('Cannot determine exactly one current monitor mode')
            settings = {k: props[k] for k in ('color-mode', 'rgb-range') if k in props}
            if 'is-underscanning' in props:
                settings['underscanning'] = props['is-underscanning']
            outputs.append([spec[0], current[0][0], settings])
        result['logical'].append([x, y, scale, transform, primary, outputs])
    if not result['logical']:
        raise ValueError('No active monitor configuration')
    return result


def validate_restore(saved, state):
    _, monitors, _, _ = state
    if saved['identities'] != sorted([list(spec) for spec, _, _ in monitors]):
        raise ValueError('Monitor topology changed; preserve the new layout')
    modes_by_connector = {spec[0]: modes for spec, modes, _ in monitors}
    for logical in saved['logical']:
        for connector, mode_id, _ in logical[5]:
            candidates = [mode for mode in modes_by_connector[connector] if mode[0] == mode_id]
            if len(candidates) != 1 or logical[2] not in candidates[0][5]:
                raise ValueError('Saved mode/scale is no longer available')


def main():
    # Import only in the live adapter; the transformation is tested without D-Bus.
    from gi.repository import Gio, GLib
    action, path = sys.argv[1:]
    path = Path(path)
    proxy = Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION, Gio.DBusProxyFlags.NONE, None,
        'org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig',
        'org.gnome.Mutter.DisplayConfig', None)

    def current():
        return proxy.call_sync('GetCurrentState', None, Gio.DBusCallFlags.NONE, 5000, None).unpack()

    state = current()
    if action == 'snapshot':
        # Delete an older cycle's snapshot before attempting to capture a new one.
        path.unlink(missing_ok=True)
        saved = snapshot(state)
        saved['boot_id'] = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
        fd, name = tempfile.mkstemp(prefix='.display-state-', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as handle:
                json.dump(saved, handle)
            os.replace(name, path)
        finally:
            if os.path.exists(name):
                os.unlink(name)
        return
    if action != 'restore':
        raise ValueError('Expected snapshot or restore')
    saved = json.loads(path.read_text())
    # Consume before any write; a MonitorsChanged event cannot replay it.
    path.unlink()
    if saved.pop('boot_id', '') != Path('/proc/sys/kernel/random/boot_id').read_text().strip():
        raise ValueError('Snapshot belongs to another boot')
    validate_restore(saved, state)
    try:
        before = snapshot(state)
    except ValueError:
        before = None
    if saved == before:
        print('Layout unchanged; no display mutation')
        return

    def variants(props):
        return {key: GLib.Variant('b' if isinstance(value, bool) else 'u', value)
                for key, value in props.items()}

    logical = [(*row[:5], [(c, m, variants(p)) for c, m, p in row[5]]) for row in saved['logical']]
    # Method 1 is temporary; it does not replace the user's persistent settings.
    args = GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})',
                        (state[0], 1, logical, variants(saved['properties'])))
    proxy.call_sync('ApplyMonitorsConfig', args, Gio.DBusCallFlags.NONE, 5000, None)
    if saved != snapshot(current()):
        raise ValueError('Mutter did not retain the requested restored layout')
    print('Restored the complete pre-suspend layout')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        sys.exit(str(error))
