pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Column {
    id: panel
    required property SystemState services
    signal advanced()
    spacing: 8
    property string tab: "output"
    property var effects: ({ running: false, presets: [], bands: [] })
    property string eqChannel: "left"
    property string effectsMessage: ""
    readonly property var nodes: Pipewire.nodes.values.filter(node => !node.isStream && (node.type & PwNodeType.Audio))
    readonly property var current: tab === "input" ? services.input : services.output
    readonly property var audio: tab === "input" ? services.microphone : services.audio
    PwObjectTracker { objects: panel.nodes }
    function refreshEffects() {
        if (panel.tab === "equalizer" && !effectsProbe.running) effectsProbe.running = true
    }
    function effectAction(args) {
        effectsAction.command = ["python3", Qt.resolvedUrl("scripts/easyeffects.py").toString().replace("file://", "")].concat(args)
        effectsAction.running = true
    }
    Component.onCompleted: refreshEffects()
    onTabChanged: refreshEffects()
    Process {
        id: effectsProbe
        command: ["python3", Qt.resolvedUrl("scripts/easyeffects.py").toString().replace("file://", ""), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.effects = JSON.parse(text)
                    panel.effectsMessage = ""
                } catch (error) {
                    panel.effects = ({ running: false, presets: [], bands: [] })
                    panel.effectsMessage = "Respuesta no válida del socket de EasyEffects."
                }
            }
        }
        stderr: StdioCollector { id: effectsProbeError }
        onExited: code => {
            if (code !== 0) {
                panel.effects = ({ running: false, presets: [], bands: [] })
                panel.effectsMessage = effectsProbeError.text.trim() || "No se pudo consultar EasyEffects."
            }
        }
    }
    Process {
        id: effectsAction
        onExited: code => {
            if (code !== 0) panel.effectsMessage = "EasyEffects no pudo completar la operación."
            panel.refreshEffects()
        }
    }
    Timer { interval: 2500; repeat: true; running: panel.tab === "equalizer"; onTriggered: panel.refreshEffects() }
    RowLayout {
        width: parent.width; spacing: 4
        Repeater {
            model: [{key:"output",label:"Salida"},{key:"input",label:"Entrada"},{key:"equalizer",label:"Ecualizador"}]
            RoryButton {
                required property var modelData
                Layout.fillWidth: true; text: modelData.label; selected: panel.tab === modelData.key
                onClicked: panel.tab = modelData.key
            }
        }
    }
    Column {
        width: parent.width; spacing: 7; visible: panel.tab !== "equalizer"
        PanelText { text: panel.current?.description || panel.current?.name || "Dispositivo no disponible"; color: "#fff0f2" }
        PanelText { text: panel.audio ? "Volumen · " + Math.round(panel.audio.volume*100) + " %" : "PipeWire no ofrece un dispositivo de audio." }
        PanelSlider { enabled: !!panel.audio; value: Math.min(1,panel.audio?.volume ?? 0); Accessible.name: panel.tab === "input" ? "Volumen del micrófono" : "Volumen de salida"; onMoved: if (panel.audio) panel.audio.volume = value }
        RoryButton { width: parent.width; enabled: !!panel.audio; selected: panel.audio?.muted ?? false; text: panel.audio?.muted ? "Activar sonido" : panel.tab === "input" ? "Silenciar micrófono" : "Silenciar salida"; onClicked: if (panel.audio) panel.audio.muted = !panel.audio.muted }
        PanelRule {}
        PanelText { text: panel.tab === "input" ? "Dispositivos de entrada" : "Dispositivos de salida"; color: "#fff0f2" }
        Repeater {
            model: panel.nodes.filter(node => panel.tab === "input" ? !!(node.type & PwNodeType.Source) : node.isSink)
            RoryButton {
                required property var modelData
                width: panel.width; alignLeft: true; enabled: modelData.ready
                selected: modelData === panel.current
                text: (modelData.description || modelData.name) + (selected ? "  ✓ Predeterminado" : "")
                onClicked: {
                    if (panel.tab === "input") Pipewire.preferredDefaultAudioSource = modelData
                    else Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }
    Column {
        width: parent.width; spacing: 8; visible: panel.tab === "equalizer"
        PanelText { text: "Ecualizador · EasyEffects"; color: "#fff0f2"; font.pixelSize: 16 }
        PanelText {
            visible: !panel.effects.running
            text: panel.effectsMessage || "EasyEffects no está ejecutándose."
        }
        RoryButton {
            width: parent.width; text: "Abrir EasyEffects"
            onClicked: {
                if (panel.effects.running) panel.effectAction(["show"])
                else Quickshell.execDetached(["easyeffects"])
            }
        }
        Column {
            width: parent.width; spacing: 8; visible: panel.effects.running
            RowLayout {
                width: parent.width
                PanelText { Layout.fillWidth: true; text: panel.effects.globalBypass ? "Efectos globales desactivados" : "Efectos globales activos" }
                PanelSwitch {
                    checked: !panel.effects.globalBypass
                    Accessible.name: "Activar efectos globales de EasyEffects"
                    onToggled: panel.effectAction(["global-bypass", checked ? "0" : "1"])
                }
            }
            PanelText { text: "Preajuste de salida"; color: "#fff0f2" }
            ComboBox {
                id: presetBox
                width: parent.width
                model: panel.effects.presets
                textRole: "name"
                enabled: count > 0 && !effectsAction.running
                currentIndex: {
                    const i = panel.effects.presets.findIndex(preset => preset.name === panel.effects.loadedPreset)
                    return i
                }
                onActivated: index => panel.effectAction(["load", currentText])
            }
            PanelText {
                visible: panel.effects.presets.length === 0
                text: "No hay preajustes locales de salida disponibles."
            }
            PanelText {
                visible: !!panel.effects.loadedPreset
                text: "Cargado: " + panel.effects.loadedPreset
            }
            PanelRule {}
            RowLayout {
                width: parent.width
                PanelText { Layout.fillWidth: true; text: panel.effects.equalizerAvailable ? "Ecualizador" : "Instancia equalizer#0 no disponible"; color: "#fff0f2" }
                PanelSwitch {
                    visible: panel.effects.equalizerAvailable
                    checked: !panel.effects.equalizerBypass
                    Accessible.name: "Activar ecualizador de salida"
                    onToggled: panel.effectAction(["eq-bypass", checked ? "0" : "1"])
                }
            }
            PanelText {
                visible: panel.effects.equalizerAvailable && panel.effects.globalBypass
                text: "El bypass global está activo; EasyEffects ignora los efectos individuales."
            }
            PanelText {
                visible: !panel.effects.equalizerAvailable
                text: "La API permite editar una instancia existente, pero no añadir el plugin desde Rory. Actívalo en EasyEffects y vuelve a consultar."
            }
            RowLayout {
                visible: panel.effects.equalizerAvailable
                width: parent.width
                PanelText { Layout.fillWidth: true; text: "Canal de edición" }
                RoryButton { text: "Izquierdo"; selected: panel.eqChannel === "left"; onClicked: panel.eqChannel = "left" }
                RoryButton { text: "Derecho"; selected: panel.eqChannel === "right"; onClicked: panel.eqChannel = "right" }
            }
            Repeater {
                model: panel.effects.equalizerAvailable ? panel.effects.bands : []
                RowLayout {
                    id: bandRow
                    required property var modelData
                    width: parent.width; spacing: 6
                    PanelText { Layout.preferredWidth: 54; text: Number(bandRow.modelData.frequency).toLocaleString(Qt.locale(), 'f', 0) + " Hz" }
                    TextField {
                        id: gainField
                        Layout.fillWidth: true
                        property bool editing: false
                        property string editedText: ""
                        text: editing ? editedText : Number(panel.eqChannel === "left" ? bandRow.modelData.left : bandRow.modelData.right).toLocaleString(Qt.locale("C"), 'f', 1)
                        color: "#fff0f2"
                        selectByMouse: true
                        validator: DoubleValidator { locale: "C" }
                        Accessible.name: "Ganancia " + bandRow.modelData.frequency + " Hz, " + panel.eqChannel
                        background: Rectangle { color: "#27191f"; radius: 5; border.color: gainField.activeFocus ? "#d22a49" : "#51303e" }
                        onActiveFocusChanged: if (!activeFocus) editing = false
                        onTextEdited: { editedText = text; editing = true }
                        onAccepted: {
                            const value = Number(text)
                            if (acceptableInput && Number.isFinite(value)) {
                                panel.effectAction(["gain", String(bandRow.modelData.index), panel.eqChannel, String(value)])
                                editing = false
                                focus = false
                            }
                        }
                    }
                    PanelText { Layout.preferredWidth: 24; text: "dB" }
                }
            }
            PanelText { visible: !!panel.effectsMessage; text: panel.effectsMessage }
        }
    }
    PanelRule {}
    RoryButton { width: parent.width; text: "⚙  Ajustes de sonido"; onClicked: panel.advanced() }
}
