pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "RoryTheme.js" as Theme

Column {
    id: panel
    required property SystemState services
    signal advanced()
    property string theme: "crimson"
    function tone(original,pink) { return Theme.tone(theme,original,pink) }
    component BatteryText: PanelText { color: panel.tone("#e1cbd0","#F7C7DA") }
    component BatteryRule: Item {
        width: parent.width
        height: 17
        PanelRule { visible: panel.theme !== "sakura" }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: "#69324D"; visible: panel.theme === "sakura"
        }
    }
    spacing: 8
    property var metrics: ({})
    property string status: ""
    function duration(seconds) {
        if (seconds === undefined || seconds === null || seconds <= 0) return "No disponible"
        const minutes = Math.floor(seconds/60)
        return Math.floor(minutes/60) + " h " + minutes%60 + " min"
    }
    function capacity(value) { return value === undefined || value === null ? "No disponible" : Number(value).toFixed(1) + " " + metrics.unit }
    function refresh() { if (!probe.running) probe.running = true }
    Component.onCompleted: refresh()
    Process {
        id: probe
        command: ["python3", Qt.resolvedUrl("scripts/battery-metrics.py").toString().replace("file://",""), panel.services.battery?.nativePath ?? ""]
        stdout: StdioCollector { onStreamFinished: { try { panel.metrics = JSON.parse(text) } catch (error) { panel.status = "No se pudieron leer las métricas." } } }
    }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: panel.refresh() }
    Item {
        width: parent.width; height: 84
        Column {
            width: parent.width-88; spacing: 4
            BatteryText { text: panel.services.batteryReady ? panel.services.charge + " %" : "—"; font.pixelSize: 36; color: panel.tone("#ffe6eb","#FFD0E1") }
            BatteryText { text: panel.services.batteryState }
        }
        Image { anchors.right: parent.right; width: 88; height: 88; source: Theme.art(panel.theme,"panel-rose"); enabled: false }
    }
    BatteryText { text: panel.services.batteryReady ? "Tiempo estimado: " + panel.duration(panel.services.battery.timeToFull || panel.services.battery.timeToEmpty) : "Batería no disponible" }
    BatteryText { text: UPower.onBattery ? "Alimentación por batería" : "Conectado a corriente"; visible: panel.services.batteryReady }
    BatteryRule {}
    BatteryText { text: "Modo de energía"; color: panel.tone("#fff0f2","#FFD0E1") }
    RowLayout {
        width: parent.width; spacing: 4
        Repeater {
            model: [{name:"Optimización",value:PowerProfile.PowerSaver},{name:"Normal",value:PowerProfile.Balanced},{name:"Rendimiento",value:PowerProfile.Performance}]
            RoryButton {
                theme: panel.theme
                required property var modelData
                Layout.fillWidth: true; textSize: 11; text: modelData.name
                selected: !!panel.metrics.profiles && PowerProfiles.profile === modelData.value
                enabled: !!panel.metrics.profiles && (modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                onClicked: { profileRequest.command = ["powerprofilesctl","set", modelData.value === PowerProfile.PowerSaver ? "power-saver" : modelData.value === PowerProfile.Performance ? "performance" : "balanced"]; profileRequest.running = true }
            }
        }
    }
    BatteryText { visible: !panel.metrics.profiles; text: panel.metrics.conflict ? "Perfiles desactivados para evitar conflicto con " + panel.metrics.conflict : "El servicio de perfiles de energía no está disponible." }
    BatteryText { visible: !!panel.metrics.profiles && !PowerProfiles.hasPerformanceProfile; text: "El hardware no ofrece el perfil Rendimiento." }
    BatteryText { visible: !!panel.status; text: panel.status }
    Process {
        id: profileRequest
        stderr: StdioCollector { id: profileError }
        onExited: code => { panel.status = code !== 0 ? profileError.text.trim() || "El sistema rechazó el cambio de perfil." : ""; panel.refresh() }
    }
    BatteryRule {}
    BatteryText { text: "Salud de la batería: " + (panel.metrics.health === undefined || panel.metrics.health === null ? "No disponible" : Number(panel.metrics.health).toFixed(1) + " %") }
    Rectangle {
        width: parent.width; height: 6; radius: 3; color: panel.tone("#492a34","#4E263F")
        Rectangle { width: parent.width*Math.min(1,Math.max(0,(panel.metrics.health ?? 0)/100)); height: 6; radius: 3; color: panel.tone("#e32b4a","#FF5B9A") }
    }
    BatteryText { text: "Capacidad actual: " + panel.capacity(panel.metrics.current) }
    BatteryText { text: "Capacidad máxima: " + panel.capacity(panel.metrics.full) }
    BatteryText { text: "Capacidad de diseño: " + panel.capacity(panel.metrics.design) }
    BatteryText { text: "Ciclos de carga: " + (panel.metrics.cycles ?? "No disponible") }
    BatteryRule {}
    BatteryText { text: "Tiempo de sesión: " + panel.duration(panel.metrics.session) }
    BatteryText { text: "Encendido del sistema: " + panel.duration(panel.metrics.uptime) }
    BatteryRule {}
    RoryButton { theme: panel.theme; width: parent.width; glyph: "power"; text: "Ajustes de energía"; onClicked: panel.advanced() }
}
