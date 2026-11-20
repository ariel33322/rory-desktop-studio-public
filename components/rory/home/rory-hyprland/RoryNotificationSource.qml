pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: source
    required property bool enabledReceiver
    property string receiverStatus: "disabled"
    property var arrival: ({})
    readonly property var notifications: (receiver.item as NotificationServer)?.trackedNotifications.values ?? []
    function timeFor(note) { return arrival[note.id] ?? null }
    function clear() { for (const note of [...notifications]) note.dismiss() }
    function check() {
        if (!enabledReceiver) {
            query.running = false
            owner.running = false
            receiverStatus = "disabled"
            return
        }
        if (receiverStatus === "ready" || query.running || owner.running) return
        receiverStatus = "checking"
        query.running = true
    }
    Component.onCompleted: check()
    onEnabledReceiverChanged: check()

    Process {
        id: query
        command: ["busctl", "--user", "--timeout=3s", "--json=short", "call",
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames"]
        stdout: StdioCollector { id: reply }
        onExited: code => {
            if (!source.enabledReceiver) return
            try {
                const names = JSON.parse(reply.text).data.flat()
                if (code !== 0) {
                    source.receiverStatus = "unavailable"
                } else if (names.includes("org.freedesktop.Notifications")) {
                    owner.running = true
                } else {
                    source.receiverStatus = "starting"
                }
            } catch (error) {
                source.receiverStatus = "unavailable"
            }
        }
    }
    Process {
        id: owner
        command: ["busctl", "--user", "--timeout=3s", "--json=short", "call",
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
            "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"]
        stdout: StdioCollector { id: ownerReply }
        onExited: code => {
            if (!source.enabledReceiver) return
            if (code !== 0) {
                source.receiverStatus = "unavailable"
                return
            }
            try {
                source.receiverStatus = Number(JSON.parse(ownerReply.text).data) === Quickshell.processId
                    ? "ready" : "external"
            } catch (error) {
                source.receiverStatus = "unavailable"
            }
        }
    }
    Loader {
        id: receiver
        active: source.enabledReceiver && (source.receiverStatus === "starting" || source.receiverStatus === "ready")
        onStatusChanged: if (status === Loader.Ready && source.receiverStatus === "starting") owner.running = true
        onActiveChanged: if (!active) source.arrival = ({})
        sourceComponent: NotificationServer {
            keepOnReload: true
            actionsSupported: true
            bodyMarkupSupported: false
            onNotification: note => {
                const next = Object.assign({}, source.arrival)
                if (!note.lastGeneration) next[note.id] = new Date()
                source.arrival = next
                note.tracked = true
            }
        }
    }
    onNotificationsChanged: {
        const next = {}
        for (const note of notifications) {
            if (arrival[note.id]) next[note.id] = arrival[note.id]
        }
        if (Object.keys(next).length !== Object.keys(arrival).length) arrival = next
    }
}
