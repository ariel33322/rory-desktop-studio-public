#!/usr/bin/env python3
"""Transient BlueZ pairing agent. JSON on pipes, no default agent or discovery changes."""
import json
import signal
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
loop = GLib.MainLoop()
pending = None
pairing = None


def emit(event, **data):
    print(json.dumps(dict(event=event, **data)), flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = 'org.bluez.Error.Rejected'


class Agent(dbus.service.Object):
    def ask(self, kind, device, ok, fail, **details):
        global pending
        if pending:
            pending[1](Rejected('Another request is active'))
        pending = (ok, fail, kind)
        emit('request', kind=kind, device=str(device), **details)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='s', async_callbacks=('ok', 'fail'))
    def RequestPinCode(self, device, ok, fail):
        self.ask('pin', device, ok, fail)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='u', async_callbacks=('ok', 'fail'))
    def RequestPasskey(self, device, ok, fail):
        self.ask('passkey', device, ok, fail)

    @dbus.service.method('org.bluez.Agent1', in_signature='ou', out_signature='', async_callbacks=('ok', 'fail'))
    def RequestConfirmation(self, device, passkey, ok, fail):
        self.ask('confirm', device, ok, fail, passkey=f'{int(passkey):06d}')

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='', async_callbacks=('ok', 'fail'))
    def RequestAuthorization(self, device, ok, fail):
        self.ask('authorize', device, ok, fail)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='', async_callbacks=('ok', 'fail'))
    def AuthorizeService(self, device, uuid, ok, fail):
        self.ask('authorize', device, ok, fail, uuid=str(uuid))

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
    def DisplayPinCode(self, device, pincode):
        emit('display', text='Introduce este PIN en el dispositivo: ' + str(pincode))

    @dbus.service.method('org.bluez.Agent1', in_signature='ouq', out_signature='')
    def DisplayPasskey(self, device, passkey, entered):
        emit('display', text=f'Código: {int(passkey):06d} · {int(entered)} dígitos introducidos')

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Cancel(self):
        global pending
        pending = None
        emit('cancelled')

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Release(self):
        emit('error', text='BlueZ ha retirado el agente de emparejamiento.')
        loop.quit()


def error(exc):
    global pairing
    pairing = None
    emit('error', text=str(exc))


def done():
    global pairing
    pairing = None
    emit('done')


def handle(source, condition):
    global pending, pairing
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = source.readline()
    if not line:
        loop.quit()
        return False
    try:
        data = json.loads(line)
        action = data.get('action')
        if action == 'answer' and pending:
            ok, fail, kind = pending
            value = str(data.get('value', ''))
            if not data.get('accept'):
                pending = None
                fail(Rejected('Rejected by user'))
            elif kind == 'pin' and 1 <= len(value) <= 16:
                pending = None
                ok(value)
            elif kind == 'passkey' and value.isascii() and value.isdigit() and len(value) <= 6:
                pending = None
                ok(dbus.UInt32(int(value)))
            elif kind in ('confirm', 'authorize'):
                pending = None
                ok()
            else:
                emit('validation', text='Introduce un PIN válido o una clave numérica de hasta 6 dígitos.')
        elif action in ('connect', 'disconnect', 'forget'):
            path = str(data['path'])
            if not path.startswith('/org/bluez/') or pairing:
                raise ValueError('Dispositivo no válido o emparejamiento en curso')
            device = bus.get_object('org.bluez', path)
            if action == 'forget':
                props = dbus.Interface(device, 'org.freedesktop.DBus.Properties')
                adapter_path = props.Get('org.bluez.Device1', 'Adapter')
                adapter = dbus.Interface(bus.get_object('org.bluez', adapter_path), 'org.bluez.Adapter1')
                adapter.RemoveDevice(dbus.ObjectPath(path), reply_handler=lambda: emit('action_done'), error_handler=error)
            else:
                interface = dbus.Interface(device, 'org.bluez.Device1')
                method = interface.Connect if action == 'connect' else interface.Disconnect
                method(reply_handler=lambda: emit('action_done'), error_handler=error, timeout=30)
        elif action == 'pair':
            path = str(data['path'])
            if not path.startswith('/org/bluez/') or pairing:
                raise ValueError('Dispositivo no válido o emparejamiento en curso')
            pairing = dbus.Interface(bus.get_object('org.bluez', path), 'org.bluez.Device1')
            pairing.Pair(reply_handler=done, error_handler=error, timeout=120)
    except Exception as exc:
        emit('error', text=str(exc))
    return True


try:
    bus = dbus.SystemBus()
    manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
    agent = Agent(bus, '/org/rory/PairingAgent')
    manager.RegisterAgent('/org/rory/PairingAgent', 'KeyboardDisplay')
    emit('ready')
    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, handle)
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    signal.signal(signal.SIGINT, lambda *_: loop.quit())
    try:
        loop.run()
    finally:
        if pending:
            pending[1](Rejected('Panel closed'))
        if pairing:
            try:
                pairing.CancelPairing()
            except dbus.DBusException:
                pass
        try:
            manager.UnregisterAgent('/org/rory/PairingAgent')
        except dbus.DBusException:
            pass
except Exception as exc:
    emit('error', text=str(exc))
    sys.exit(1)
