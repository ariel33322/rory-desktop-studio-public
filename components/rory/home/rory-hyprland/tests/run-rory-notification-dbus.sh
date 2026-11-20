#!/bin/sh
set -eu
project=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
trial=$(mktemp -d /tmp/rory-notify-dbus.XXXXXX)
trap 'rm -rf -- "$trial"' EXIT
mkdir -m700 "$trial/runtime"
cp "$project/RoryNotificationSource.qml" "$trial/"
cat > "$trial/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    id: test
    property int stage: 0
    RoryNotificationSource { id: source; enabledReceiver: true }
    Process {
        id: sender
        command: ["notify-send", "-a", "Rory D-Bus Test", "Rory D-Bus", "Mensaje de prueba"]
        onExited: code => { if (code !== 0) Qt.exit(1) }
    }
    Timer {
        interval: 125
        repeat: true
        running: true
        onTriggered: {
            if (source.receiverStatus === "external" || source.receiverStatus === "unavailable") Qt.exit(1)
            if (test.stage === 0 && source.receiverStatus === "ready") {
                test.stage = 1
                sender.running = true
            } else if (test.stage === 1 && source.notifications.length === 1) {
                const note = source.notifications[0]
                if (note.summary !== "Rory D-Bus" || note.body !== "Mensaje de prueba") { Qt.exit(1); return }
                test.stage = 2
                note.dismiss()
            } else if (test.stage === 2 && source.notifications.length === 0) {
                test.stage = 3
                sender.running = true
            } else if (test.stage === 3 && source.notifications.length === 1 && !sender.running) {
                test.stage = 4
                sender.running = true
            } else if (test.stage === 4 && source.notifications.length === 2) {
                test.stage = 5
                source.clear()
            } else if (test.stage === 5 && source.notifications.length === 0) {
                console.log("RORY_NOTIFICATION_DBUS_PASS")
                Qt.exit(0)
            }
        }
    }
}
QML
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    XDG_RUNTIME_DIR="$trial/runtime" XDG_CACHE_HOME="$trial" QT_QPA_PLATFORM=offscreen \
    timeout 15 dbus-run-session -- qs --no-color -p "$trial/shell.qml" > "$trial/result" 2>&1 || {
    cat "$trial/result"; exit 1;
}
cat "$trial/result"
rg -q RORY_NOTIFICATION_DBUS_PASS "$trial/result"
