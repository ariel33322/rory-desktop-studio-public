pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Column {
    id: panel
    required property SystemState services
    signal advanced()
    signal revealTop()
    spacing: 8
    property string status: ""
    property var request: null
    property var forgetDevice: null
    onRequestChanged: if (request) revealTop()
    onForgetDeviceChanged: if (forgetDevice) revealTop()
    property bool agentReady: false
    property bool busy: false
    property bool ownsDiscovery: false
    property var scanningAdapter: null
    readonly property var devices: services.adapter?.devices.values ?? []
    function deviceAction(action, device) {
        status = ""
        if (agentReady) agent.write(JSON.stringify({action:action,path:device.dbusPath})+"\n")
        else if (action === "connect") device.connect()
        else if (action === "disconnect") device.disconnect()
        else if (action === "forget") device.forget()
    }
    function answer(accept) {
        agent.write(JSON.stringify({action:"answer", accept:accept, value:pin.text})+"\n")
        pin.text = ""
        if (!accept || !["pin","passkey"].includes(request?.kind)) request = null
    }
    Component.onDestruction: {
        if (ownsDiscovery && scanningAdapter) scanningAdapter.discovering = false
    }
    Process {
        id: agent
        command: ["python3", Qt.resolvedUrl("scripts/bluetooth-agent.py").toString().replace("file://", "")]
        running: true; stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    if (message.event === "ready") panel.agentReady = true
                    else if (message.event === "request") { panel.request = message; pin.forceActiveFocus() }
                    else if (message.event === "action_done") panel.status = "Operación completada."
                    else if (message.event === "validation" || message.event === "display") panel.status = message.text
                    else if (["error","done","cancelled"].includes(message.event)) {
                        panel.request = null; panel.busy = false
                        panel.status = message.event === "done" ? "Emparejamiento completado. Ya puedes conectar el dispositivo." : message.text || "Emparejamiento cancelado."
                    }
                } catch (error) { panel.status = "Respuesta de BlueZ no válida." }
            }
        }
        onExited: code => { panel.agentReady = false; if (code !== 0 && !panel.status) panel.status = "Agente BlueZ no disponible." }
    }
    RowLayout {
        width: parent.width
        PanelText { Layout.fillWidth: true; text: panel.services.bluetoothLabel; color: "#fff0f2" }
        PanelSwitch {
            checked: panel.services.adapter?.enabled ?? false
            enabled: !!panel.services.adapter && [BluetoothAdapterState.Enabled,BluetoothAdapterState.Disabled].includes(panel.services.adapter.state)
            Accessible.name: "Activar Bluetooth"; onToggled: panel.services.toggleBluetooth()
        }
    }
    PanelText { text: panel.services.adapter ? "Adaptador: " + panel.services.adapter.name + (panel.services.adapter.discoverable ? " · Visible" : " · No visible") : "No hay adaptador disponible" }
    PanelRule {}
    component DeviceRow: Column {
        id: row
        required property var device
        width: panel.width; spacing: 4
        PanelText {
            text: row.device.name + (row.device.connected ? "  ✓ Conectado" : row.device.paired ? " · Vinculado" : "")
                + (row.device.batteryAvailable ? " · " + Math.round(row.device.battery*100) + " %" : "")
            font.pixelSize: 13; color: "#fff0f2"
        }
        RowLayout {
            width: parent.width
            RoryButton {
                Layout.fillWidth: true
                text: row.device.pairing ? "Emparejando…" : row.device.connected ? "Desconectar" : row.device.paired ? "Conectar" : "Emparejar"
                enabled: !!panel.services.adapter?.enabled && !row.device.pairing && (row.device.paired || (panel.agentReady && !panel.busy))
                onClicked: {
                    if (row.device.connected) panel.deviceAction("disconnect",row.device)
                    else if (row.device.paired) panel.deviceAction("connect",row.device)
                    else { panel.busy = true; panel.status = "Emparejando " + row.device.name + "…"; agent.write(JSON.stringify({action:"pair",path:row.device.dbusPath})+"\n") }
                }
            }
            RoryButton { visible: row.device.paired; text: "Quitar"; onClicked: panel.forgetDevice = row.device }
        }
    }
    Column {
        width: parent.width; spacing: 5; visible: !!panel.request
        PanelText { text: panel.request?.kind === "confirm" ? "¿Coincide este código? " + panel.request.passkey : panel.request?.kind === "authorize" ? "¿Autorizar este dispositivo?" : "Introduce el PIN o la clave del dispositivo" }
        TextField {
            id: pin; width: parent.width; visible: ["pin","passkey"].includes(panel.request?.kind)
            echoMode: TextInput.Password; color: "#fff0f3"; maximumLength: panel.request?.kind === "passkey" ? 6 : 16
            background: Rectangle { color: "#27191f"; radius: 5; border.color: "#9f1734" }
        }
        RowLayout {
            RoryButton { text: "Aceptar"; onClicked: panel.answer(true) }
            RoryButton { text: "Rechazar"; onClicked: panel.answer(false) }
        }
    }
    Column {
        width: parent.width; spacing: 5; visible: !!panel.forgetDevice
        PanelText { text: "¿Eliminar el emparejamiento de " + (panel.forgetDevice?.name ?? "") + "?" }
        RowLayout {
            RoryButton { text: "Eliminar"; onClicked: { if (panel.forgetDevice) panel.deviceAction("forget",panel.forgetDevice); panel.forgetDevice = null } }
            RoryButton { text: "Cancelar"; onClicked: panel.forgetDevice = null }
        }
    }
    PanelText { text: "Dispositivos vinculados"; color: "#fff0f2" }
    Repeater { model: panel.devices.filter(device => device.paired || device.connected); DeviceRow { required property var modelData; device: modelData } }
    PanelRule {}
    PanelText { text: "Dispositivos cercanos"; color: "#fff0f2" }
    Repeater { model: panel.devices.filter(device => !device.paired && !device.connected); DeviceRow { required property var modelData; device: modelData } }
    PanelText { text: panel.status; visible: !!text }
    RoryButton {
        width: parent.width; enabled: !!panel.services.adapter?.enabled
        text: panel.services.adapter?.discovering ? "Detener búsqueda" : "Buscar dispositivos"
        onClicked: {
            const adapter = panel.services.adapter
            if (adapter.discovering && !panel.ownsDiscovery) { panel.status = "Otra aplicación está buscando dispositivos."; return }
            if (adapter.discovering) { adapter.discovering = false; panel.ownsDiscovery = false }
            else { panel.scanningAdapter = adapter; adapter.discovering = true; panel.ownsDiscovery = true; discoveryLimit.restart() }
        }
    }
    Timer { id: discoveryLimit; interval: 30000; onTriggered: { if (panel.ownsDiscovery && panel.scanningAdapter) panel.scanningAdapter.discovering = false; panel.ownsDiscovery = false } }
    RoryButton { width: parent.width; text: "⚙  Ajustes de Bluetooth"; onClicked: panel.advanced() }
}
