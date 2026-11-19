pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Column {
    id: panel
    required property SystemState services
    signal advanced()
    signal revealTop()
    spacing: 8
    property var passwordNetwork: null
    property string status: ""
    property bool oldScanner: false
    property var scanningDevice: null
    readonly property var connectedNetwork: (services.wifi?.networks.values ?? []).find(network => network.connected) ?? null
    readonly property var networks: Networking.wifiEnabled ? (services.wifi?.networks.values ?? [])
        .filter(network => network.name.length > 0)
        .sort((a,b) => Number(b.connected)-Number(a.connected) || b.signalStrength-a.signalStrength) : []

    Component.onCompleted: {
        scanningDevice = services.wifi
        if (scanningDevice) { oldScanner = scanningDevice.scannerEnabled; scanningDevice.scannerEnabled = true }
    }
    Component.onDestruction: {
        if (scanningDevice) scanningDevice.scannerEnabled = oldScanner
        password.text = ""
    }
    function connectNetwork(network) {
        status = ""
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe)
            network.connect()
        else askPassword(network)
    }
    function askPassword(network) {
        if (![WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)) {
            status = "Esta red requiere autenticación avanzada. Utiliza Ajustes de red."
            return
        }
        passwordNetwork = network
        revealTop()
        password.forceActiveFocus()
    }
    RowLayout {
        width: parent.width
        PanelText { Layout.fillWidth: true; text: panel.connectedNetwork?.name || (Networking.wifiEnabled ? "Sin conexión Wi-Fi" : "Wi-Fi desactivado"); font.pixelSize: 15; color: "#fff0f2" }
        PanelSwitch {
            enabled: !!panel.services.wifi && Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled
            Accessible.name: "Activar Wi-Fi"
            onToggled: panel.services.toggleWifi()
        }
    }
    PanelText { text: !Networking.wifiHardwareEnabled ? "Wi-Fi bloqueado por el hardware" : panel.connectedNetwork ? "Conectada · señal " + Math.round((panel.connectedNetwork.signalStrength ?? 0)*100) + " %" : "Sin conexión Wi-Fi" }
    RoryButton {
        width: parent.width; visible: !!panel.connectedNetwork
        text: "Desconectar"; onClicked: panel.connectedNetwork?.disconnect()
    }
    PanelRule {}
    PanelText { text: "Redes disponibles"; color: "#fff0f2" }
    Column {
        visible: !!panel.passwordNetwork; width: parent.width; spacing: 6
        PanelText { text: "Contraseña de " + (panel.passwordNetwork?.name ?? "") }
        TextField {
            id: password
            width: parent.width; echoMode: TextInput.Password
            color: "#ffe7ed"; placeholderText: "Contraseña"; selectByMouse: true
            background: Rectangle { radius: 6; color: "#23191f"; border.color: "#a4233f" }
            onAccepted: submit.clicked()
        }
        RowLayout {
            width: parent.width
            RoryButton {
                id: submit; Layout.fillWidth: true; text: "Conectar"; enabled: password.text.length > 0
                onClicked: {
                    if (!panel.passwordNetwork || !password.text.length) return
                    panel.passwordNetwork.connectWithPsk(password.text)
                    password.text = ""; panel.passwordNetwork = null
                }
            }
            RoryButton { text: "Cancelar"; onClicked: { password.text = ""; panel.passwordNetwork = null } }
        }
    }
    Repeater {
        model: panel.networks
        delegate: Column {
            id: row
            required property var modelData
            width: panel.width; spacing: 3
            RoryButton {
                width: parent.width; alignLeft: true
                glyph: "network"; glyphLevel: row.modelData.signalStrength
                selected: row.modelData.connected
                enabled: !row.modelData.stateChanging
                text: row.modelData.name + (row.modelData.connected ? "  ✓" : "")
                    + (row.modelData.security === WifiSecurityType.Open ? "" : "  ⌑")
                hint: Math.round(row.modelData.signalStrength*100) + " % · " + (row.modelData.known ? "Guardada" : "Nueva red")
                onClicked: if (!row.modelData.connected) panel.connectNetwork(row.modelData)
            }
            Connections {
                target: row.modelData
                function onConnectionFailed(reason) {
                    panel.status = "No se pudo conectar a " + row.modelData.name + " · " + reason
                    if (String(reason) === "NoSecrets" || reason === ConnectionFailReason.NoSecrets) panel.askPassword(row.modelData)
                }
            }
        }
    }
    PanelText { visible: !panel.networks.length; text: Networking.wifiEnabled ? "No se detectan redes. Pulsa Actualizar." : "Wi-Fi desactivado" }
    PanelText { visible: !!panel.status; text: panel.status }
    PanelRule {}
    RowLayout {
        width: parent.width
        RoryButton { Layout.fillWidth: true; text: "⚙  Ajustes de red"; onClicked: panel.advanced() }
        RoryButton {
            text: "↻"; hint: "Actualizar redes"; enabled: !!panel.services.wifi && !scan.running && Networking.wifiEnabled
            onClicked: { scan.command = ["nmcli", "device", "wifi", "rescan", "ifname", panel.services.wifi.name]; scan.running = true }
        }
    }
    Process {
        id: scan
        stderr: StdioCollector { id: scanError }
        onExited: code => { if (code !== 0) panel.status = scanError.text.trim() || "No se pudo actualizar la búsqueda." }
    }
}
