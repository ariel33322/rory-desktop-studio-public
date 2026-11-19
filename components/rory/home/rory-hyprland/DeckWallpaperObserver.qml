pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: observer
    visible: false
    required property string endpoint
    required property string referenceOutput
    property string path: ""
    property int nextId: 0
    property int subscription: 0
    property int snapshot: 0
    property bool refreshPending: false
    property int retryMs: 250

    function send(method) {
        const id = ++nextId
        wire.write(JSON.stringify({id: id, method: method, params: {}}) + "\n")
        wire.flush()
        return id
    }

    function refresh() {
        if (snapshot) refreshPending = true
        else snapshot = send("wall.outputs")
    }

    function receive(line) {
        try {
            const message = JSON.parse(line)
            if (message.id === subscription) {
                subscription = 0
                if (message.result?.subscribed !== true) {
                    wire.connected = false
                    return
                }
                retryMs = 250
                refresh()
            } else if (message.event === "skwd.wall.applied" && !subscription) {
                if (message.data?.output === "*" || message.data?.output === referenceOutput)
                    refresh()
            } else if (message.id === snapshot) {
                snapshot = 0
                if (refreshPending) {
                    refreshPending = false
                    refresh()
                    return
                }
                const outputs = message.result?.outputs
                if (!Array.isArray(outputs)) {
                    wire.connected = false
                    return
                }
                const output = outputs.find(entry => entry.connected && entry.name === referenceOutput)
                if (output && typeof output.path === "string" && output.path.startsWith("/"))
                    path = output.path
                else if (output)
                    path = ""
            }
        } catch (error) {
            console.warn("Respuesta de Deck inválida:", error)
            wire.connected = false
        }
    }

    onReferenceOutputChanged: if (wire.connected && !subscription) refresh()

    Socket {
        id: wire
        path: observer.endpoint
        parser: SplitParser { onRead: line => observer.receive(line) }
        onConnectionStateChanged: {
            observer.subscription = 0
            observer.snapshot = 0
            observer.refreshPending = false
            if (connected) {
                reconnect.stop()
                observer.subscription = observer.send("subscribe")
            } else if (observer.endpoint) {
                reconnect.start()
            }
        }
        onError: if (!connected && observer.endpoint && !reconnect.running) reconnect.start()
    }

    Timer {
        id: reconnect
        interval: observer.retryMs
        onTriggered: {
            observer.retryMs = Math.min(observer.retryMs * 2, 10000)
            wire.connected = true
        }
    }

    Component.onCompleted: if (endpoint) wire.connected = true
}
