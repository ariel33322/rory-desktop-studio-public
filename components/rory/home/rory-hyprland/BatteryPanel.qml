pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Column {
    id: panel
    required property SystemState services
    signal advanced()
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
            PanelText { text: panel.services.batteryReady ? panel.services.charge + " %" : "—"; font.pixelSize: 36; color: "#ffe6eb" }
            PanelText { text: panel.services.batteryState }
        }
        Image { anchors.right: parent.right; width: 88; height: 88; source: "assets/panel-rose.svg"; enabled: false }
    }
    PanelText { text: panel.services.batteryReady ? "Tiempo estimado: " + panel.duration(panel.services.battery.timeToFull || panel.services.battery.timeToEmpty) : "Batería no disponible" }
    PanelRule {}
    PanelText { text: "Modo de energía"; color: "#fff0f2" }
    RowLayout {
        width: parent.width; spacing: 4
        Repeater {
            model: [{name:"Optimización",value:PowerProfile.PowerSaver},{name:"Normal",value:PowerProfile.Balanced},{name:"Rendimiento",value:PowerProfile.Performance}]
            RoryButton {
                required property var modelData
                Layout.fillWidth: true; textSize: 11; text: modelData.name
                selected: !!panel.metrics.profiles && PowerProfiles.profile === modelData.value
                enabled: !!panel.metrics.profiles && (modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                onClicked: { profileRequest.command = ["powerprofilesctl","set", modelData.value === PowerProfile.PowerSaver ? "power-saver" : modelData.value === PowerProfile.Performance ? "performance" : "balanced"]; profileRequest.running = true }
            }
        }
    }
    PanelText { visible: !panel.metrics.profiles; text: panel.metrics.conflict ? "Perfiles desactivados para evitar conflicto con " + panel.metrics.conflict : "El servicio de perfiles de energía no está disponible." }
    PanelText { visible: !!panel.metrics.profiles && !PowerProfiles.hasPerformanceProfile; text: "El hardware no ofrece el perfil Rendimiento." }
    PanelText { visible: !!panel.status; text: panel.status }
    Process {
        id: profileRequest
        stderr: StdioCollector { id: profileError }
        onExited: code => { panel.status = code !== 0 ? profileError.text.trim() || "El sistema rechazó el cambio de perfil." : ""; panel.refresh() }
    }
    PanelRule {}
    PanelText { text: "Salud de la batería: " + (panel.metrics.health === undefined || panel.metrics.health === null ? "No disponible" : Number(panel.metrics.health).toFixed(1) + " %") }
    Rectangle {
        width: parent.width; height: 6; radius: 3; color: "#492a34"
        Rectangle { width: parent.width*Math.min(1,Math.max(0,(panel.metrics.health ?? 0)/100)); height: 6; radius: 3; color: "#e32b4a" }
    }
    PanelText { text: "Capacidad actual: " + panel.capacity(panel.metrics.current) }
    PanelText { text: "Capacidad máxima: " + panel.capacity(panel.metrics.full) }
    PanelText { text: "Capacidad de diseño: " + panel.capacity(panel.metrics.design) }
    PanelText { text: "Ciclos de carga: " + (panel.metrics.cycles ?? "No disponible") }
    PanelRule {}
    PanelText { text: "Tiempo de sesión: " + panel.duration(panel.metrics.session) }
    PanelText { text: "Encendido del sistema: " + panel.duration(panel.metrics.uptime) }
    PanelRule {}
    RoryButton { width: parent.width; text: "⚙  Ajustes de energía"; onClicked: panel.advanced() }
}
