pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root
    property var panelOwner: null
    readonly property date now: clock.date
    readonly property var output: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    readonly property var microphone: input?.ready ? input.audio : null
    readonly property var audio: output?.ready ? output.audio : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var pairedDevices: (adapter?.devices.values ?? [])
        .filter(device => device.paired || device.connected)
    readonly property var bluetoothConnections: pairedDevices.filter(device => device.connected)
    readonly property var interfaces: Networking.devices.values
    readonly property var wifi: interfaces.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var activeNetwork: {
        for (const device of interfaces) {
            const network = device.networks?.values.find(entry => entry.connected)
            if (network) return network
        }
        return null
    }
    readonly property var savedNetworks: (wifi?.networks.values ?? [])
        .filter(network => network.known && !network.connected)
    readonly property var battery: UPower.devices.values.find(device => device.isLaptopBattery && device.isPresent) ?? null
    readonly property bool batteryReady: battery?.ready ?? false
    readonly property int charge: batteryReady ? Math.round(battery.percentage * 100) : -1
    readonly property string batteryState: !batteryReady ? "Batería no disponible"
        : battery.state === UPowerDeviceState.Charging ? "Cargando"
        : battery.state === UPowerDeviceState.Discharging ? "En batería"
        : battery.state === UPowerDeviceState.FullyCharged ? "Carga completa"
        : "Estado de carga desconocido"
    readonly property string networkLabel: activeNetwork?.name
        || (interfaces.some(device => device.connected) ? "Conectada"
        : interfaces.length ? "Sin conexión" : "Red no disponible")
    readonly property string bluetoothLabel: !adapter ? "Bluetooth no disponible"
        : adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth bloqueado"
        : bluetoothConnections.length ? bluetoothConnections.map(device => device.name).join(", ")
        : adapter.enabled ? "Bluetooth activo" : "Bluetooth apagado"

    function toggleWifi() {
        if (wifi && Networking.wifiHardwareEnabled) Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleBluetooth() {
        if (adapter && adapter.state !== BluetoothAdapterState.Blocked) adapter.enabled = !adapter.enabled
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    PwObjectTracker {
        objects: [root.output, root.input].filter(node => node !== null)
    }
}
