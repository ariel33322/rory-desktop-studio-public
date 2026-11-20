pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "RoryTheme.js" as Theme
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
    property bool crimsonMode:false
    property string theme:"crimson"
    component MenuButton: RoryButton {tooltipEnabled:!panel.crimsonMode;theme:panel.theme}
    property var passwordNetwork: null
    property string status: ""
    property bool oldScanner: false
    property var scanningDevice: null
    readonly property var connectedNetwork: (services.wifi?.networks.values ?? []).find(network => network.connected) ?? null
    readonly property var networks: Networking.wifiEnabled ? (services.wifi?.networks.values ?? [])
        .filter(network => network.name.length > 0)
        .sort((a,b) => Number(b.connected)-Number(a.connected) || b.signalStrength-a.signalStrength) : []

    readonly property var listedNetworks: crimsonMode ? networks.filter(network=>!network.connected) : networks
    Component.onCompleted: {
        scanningDevice = services.wifi
        if (scanningDevice) { oldScanner = scanningDevice.scannerEnabled; scanningDevice.scannerEnabled = true }
    }
    Component.onDestruction: {
        if (scanningDevice) scanningDevice.scannerEnabled = oldScanner
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
        PanelText { Layout.fillWidth: true; text: panel.crimsonMode ? "Activar Wi-Fi" : panel.connectedNetwork?.name || (Networking.wifiEnabled ? "Sin conexión Wi-Fi" : "Wi-Fi desactivado"); font.pixelSize: 15; color: Theme.tone(panel.theme,"#fff0f2","#F7C7DA") }
        PanelSwitch {
            theme:panel.theme
            enabled: !!panel.services.wifi && Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled
            Accessible.name: "Activar Wi-Fi"
            onToggled: panel.services.toggleWifi()
        }
    }
    PanelText { text: !panel.services.wifi ? "Adaptador Wi-Fi no disponible" : !Networking.wifiHardwareEnabled ? "Wi-Fi bloqueado por el hardware" : panel.connectedNetwork ? "Conectada · señal " + Math.round((panel.connectedNetwork.signalStrength ?? 0)*100) + " %" : "Sin conexión Wi-Fi" }
    PanelText { visible:panel.crimsonMode && !!panel.connectedNetwork;text:"Red conectada";color:Theme.tone(panel.theme,"#ffd1df","#FF9DC3") }
    NetworkRow { visible:panel.crimsonMode && !!panel.connectedNetwork; network:panel.connectedNetwork }
    MenuButton {
        width: parent.width; visible: !!panel.connectedNetwork
        text: "Desconectar"; onClicked: panel.connectedNetwork?.disconnect()
    }
    PanelRule {}
    PanelText { text: "Redes disponibles"; color: Theme.tone(panel.theme,"#fff0f2","#F7C7DA") }
    Column {
        visible: !!panel.passwordNetwork; width: parent.width; spacing: 6
        PanelText { text: "Contraseña de " + (panel.passwordNetwork?.name ?? "") }
        TextField {
            id: password
            width: parent.width; echoMode: TextInput.Password
            color: Theme.tone(panel.theme,"#ffe7ed","#F7C7DA"); placeholderText: "Contraseña"; selectByMouse: true
            background: Rectangle { radius: 6; color: Theme.tone(panel.theme,"#23191f","#25101E"); border.color: Theme.tone(panel.theme,"#a4233f","#FF5B9A") }
            onAccepted: submit.clicked()
        }
        RowLayout {
            width: parent.width
            MenuButton {
                id: submit; Layout.fillWidth: true; text: "Conectar"; enabled: password.text.length > 0
                onClicked: {
                    if (!panel.passwordNetwork || !password.text.length) return
                    panel.passwordNetwork.connectWithPsk(password.text)
                    password.text = ""; panel.passwordNetwork = null
                }
            }
            MenuButton { text: "Cancelar"; onClicked: { password.text = ""; panel.passwordNetwork = null } }
        }
    }
    component NetworkRow: Column {
        id: row
        required property var network
        width: panel.width; spacing: 3
        MenuButton {
            width: parent.width; alignLeft: true
            height:panel.crimsonMode ? 44 : implicitHeight
            glyph: "network"; glyphLevel: row.network?.signalStrength ?? 0
            selected: row.network?.connected ?? false
            enabled: !!row.network && !row.network.stateChanging
            text: !row.network ? "" : row.network.name + (row.network.connected ? "  ✓" : "")
                + (row.network.security === WifiSecurityType.Open ? "" : "  ⌑")
            hint: !row.network ? "" : Math.round(row.network.signalStrength*100) + " % · " + (row.network.known ? "Guardada" : "Nueva red")
            onClicked: if (row.network && !row.network.connected) panel.connectNetwork(row.network)
        }
        Connections {
            target: row.network
            function onConnectionFailed(reason) {
                panel.status = "No se pudo conectar a " + row.network.name + " · " + reason
                if (String(reason) === "NoSecrets" || reason === ConnectionFailReason.NoSecrets) panel.askPassword(row.network)
            }
        }
    }
    Repeater {
        model:panel.listedNetworks
        NetworkRow {required property var modelData;network:modelData}
    }
    PanelText { visible: !panel.listedNetworks.length; text: Networking.wifiEnabled ? "No se detectan redes. Pulsa Actualizar." : "Wi-Fi desactivado" }
    PanelText { visible: !!panel.status; text: panel.status }
    PanelRule {}
    RowLayout {
        width: parent.width
        MenuButton { Layout.fillWidth: true; text: panel.crimsonMode ? "Más ajustes" : "⚙  Ajustes de red"; onClicked: panel.advanced() }
        MenuButton {
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
