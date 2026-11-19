#!/usr/bin/env python3
"""Read-only battery and session metrics. Missing values remain null."""
import json
import os
from pathlib import Path
import sys
import time


def read_number(path):
    try:
        value = float(path.read_text().strip())
        return value if value >= 0 else None
    except (OSError, ValueError):
        return None


def metrics():
    data = dict(health=None, full=None, design=None, current=None, unit=None, cycles=None,
                session=None, uptime=None, profiles=False, conflict='', error='')
    try:
        data['uptime'] = float(Path('/proc/uptime').read_text().split()[0])
    except (OSError, ValueError):
        pass
    native = Path(sys.argv[1]).name if len(sys.argv) > 1 else ''
    candidates = list(Path('/sys/class/power_supply').glob('*'))
    batteries = []
    for path in candidates:
        try:
            if (path / 'type').read_text().strip() == 'Battery':
                batteries.append(path)
        except OSError:
            pass
    battery = next((p for p in batteries if p.name == native), batteries[0] if batteries else None)
    if battery:
        for prefix, unit, divisor in [('energy', 'Wh', 1000000), ('charge', 'mAh', 1000)]:
            full = read_number(battery / (prefix + '_full'))
            design = read_number(battery / (prefix + '_full_design'))
            if full is not None and design:
                data.update(full=full/divisor, design=design/divisor, unit=unit, health=100*full/design)
                now = read_number(battery / (prefix + '_now'))
                data['current'] = now/divisor if now is not None else None
                break
        data['cycles'] = read_number(battery / 'cycle_count')
    try:
        import dbus
        bus = dbus.SystemBus()
        dbus_manager = dbus.Interface(bus.get_object('org.freedesktop.DBus', '/org/freedesktop/DBus'), 'org.freedesktop.DBus')
        profile_service = any(dbus_manager.NameHasOwner(name) for name in ('org.freedesktop.UPower.PowerProfiles', 'net.hadess.PowerProfiles'))
        systemd = dbus.Interface(bus.get_object('org.freedesktop.systemd1', '/org/freedesktop/systemd1'), 'org.freedesktop.systemd1.Manager')
        conflicts = systemd.ListUnitsByPatterns(['active'], ['tlp.service', 'tuned.service', 'auto-cpufreq.service'])
        data['profiles'] = profile_service and not conflicts
        if conflicts:
            data['conflict'] = ', '.join(str(unit[0]) for unit in conflicts)
            data['profiles'] = False
        session_id = os.environ.get('XDG_SESSION_ID')
        if session_id:
            manager = dbus.Interface(bus.get_object('org.freedesktop.login1', '/org/freedesktop/login1'), 'org.freedesktop.login1.Manager')
            path = manager.GetSession(session_id)
            props = dbus.Interface(bus.get_object('org.freedesktop.login1', path), 'org.freedesktop.DBus.Properties')
            timestamp = int(props.Get('org.freedesktop.login1.Session', 'Timestamp'))/1000000
            if timestamp > 0:
                data['session'] = max(0, time.time()-timestamp)
    except Exception as exc:
        data['error'] = str(exc)
    return data


if __name__ == '__main__':
    print(json.dumps(metrics(), allow_nan=False))
