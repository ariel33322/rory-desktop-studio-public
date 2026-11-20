pragma ComponentBehavior: Bound
import "GeometryEngine.js" as Geometry
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property url storagePath: "file://" + Quickshell.shellPath(".wallpaper-settings.ini")
    property alias imageUrl: saved.imageUrl
    property bool externalWallpaper: false
    property string observedWallpaper: ""
    readonly property string activeWallpaper: externalWallpaper ? observedWallpaper : imageUrl
    property alias fitMode: saved.fitMode
    property alias dim: saved.dim
    property alias galleryFolder: saved.galleryFolder
    property var studioVisibility:null
    readonly property bool effectiveVisualizerEnabled: studioVisibility === null ? visualizerEnabled : Boolean(studioVisibility)
    property alias visualizerEnabled: saved.visualizerEnabled
    readonly property string linearDefaults: JSON.stringify(Geometry.linearDefaults())
    property alias visualizerLinearData: linearPreferences.data
    readonly property var visualizerLinear: Geometry.linearConfig(visualizerLinearData) || Geometry.linearDefaults()
    readonly property bool spectrumEffect: visualizerEffect === "radial" || visualizerEffect === "linear"
    property alias visualizerEffect: saved.visualizerEffect
    property alias visualizerIntensity: saved.visualizerIntensity
    property alias visualizerColor: saved.visualizerColor
    property alias visualizerSensitivity: saved.visualizerSensitivity
    property alias visualizerTestMode: saved.visualizerTestMode
    property alias visualizerBarCount: saved.visualizerBarCount
    property alias visualizerBarLength: saved.visualizerBarLength
    property alias visualizerBarThickness: saved.visualizerBarThickness
    property alias visualizerBarGap: saved.visualizerBarGap
    property alias visualizerCenterX: saved.visualizerCenterX
    property alias visualizerCenterY: saved.visualizerCenterY
    property alias visualizerWidth: saved.visualizerWidth
    property alias visualizerHeight: saved.visualizerHeight
    // Neutral size factors preserve the geometry of existing settings and profiles.
    readonly property real visualizerEffectiveRadiusX: visualizerRadiusX * visualizerWidth / 584
    readonly property real visualizerEffectiveRadiusY: visualizerRadiusY * visualizerHeight / 550
    property alias visualizerRadiusX: saved.visualizerRadiusX
    property alias visualizerRadiusY: saved.visualizerRadiusY
    property alias visualizerShapeMode: saved.visualizerShapeMode
    property alias visualizerIndependentVertices: saved.visualizerIndependentVertices
    property alias visualizerGeometry: saved.visualizerGeometry
    property alias visualizerShapeData: saved.visualizerShapeData
    property alias visualizerScale: saved.visualizerScale
    property alias visualizerOffset: saved.visualizerOffset
    property alias visualizerOrientation: saved.visualizerOrientation
    property alias visualizerOpacity: saved.visualizerOpacity
    property alias visualizerGlow: saved.visualizerGlow
    property alias visualizerGlowEnabled: saved.visualizerGlowEnabled
    property alias visualizerGlowIntensity: saved.visualizerGlowIntensity
    property alias visualizerGlowSensitivity: saved.visualizerGlowSensitivity
    property alias visualizerGlowSmoothing: saved.visualizerGlowSmoothing
    property alias visualizerSmoothing: saved.visualizerSmoothing
    property alias visualizerAttack: saved.visualizerAttack
    property alias visualizerBass: saved.visualizerBass
    property alias visualizerProfile1: saved.visualizerProfile1
    property alias visualizerProfile2: saved.visualizerProfile2
    property alias visualizerProfile3: saved.visualizerProfile3
    property alias visualizerEditorX: saved.visualizerEditorX
    property alias visualizerEditorY: saved.visualizerEditorY
    property alias visualizerEditorWidth: saved.visualizerEditorWidth
    property alias visualizerEditorHeight: saved.visualizerEditorHeight
    property alias visualizerEditorCategory: saved.visualizerEditorCategory
    property alias visualizerEditorCollapsed: saved.visualizerEditorCollapsed
    property bool visualizerEditorOpen: false
    property bool visualizerPointerEditMode: false
    property var profileManager:null
    property var studioController:null
    function setVisualizerVisibility(value) {
        if(profileManager?.associationManager)profileManager.associationManager.setAudioVisibility(value)
        else if(profileManager)profileManager.controller.setValue("visualizerEnabled",value)
        else visualizerEnabled=value
    }
    readonly property var silenceDefaults: ({
        visualizerHideSilentBars:false, visualizerSilenceThreshold:0.5,
        visualizerSilenceHold:600, visualizerSilenceFade:250
    })
    property alias visualizerHideSilentBars: silencePreferences.visualizerHideSilentBars
    property alias visualizerSilenceThreshold: silencePreferences.visualizerSilenceThreshold
    property alias visualizerSilenceHold: silencePreferences.visualizerSilenceHold
    property alias visualizerSilenceFade: silencePreferences.visualizerSilenceFade
    readonly property real barSilenceOpacity: silence.barOpacity
    function resetBarSilence() { silence.reset() }
    onImageUrlChanged: resetBarSilence()
    BarSilence {
        id: silence
        monitoring: root.visualizerAudioActive && root.visualizerHideSilentBars
        samples: root.spectrum
        threshold: root.visualizerSilenceThreshold
        holdTime: root.visualizerSilenceHold
        fadeTime: root.visualizerSilenceFade
    }
    property var spectrum: []
    property string visualizerStatus: ""
    // Audio follows visualizer controls, independently of the selected image.
    readonly property bool visualizerAudioActive: effectiveVisualizerEnabled && !visualizerTestMode
        && spectrumEffect
    onVisualizerAudioActiveChanged: {
        if (!visualizerAudioActive) {
            spectrum = []
            visualizerStatus = ""
        }
    }
    readonly property bool referenceImageActive: {
        const source = decodeURIComponent(imageUrl.toString())
        return source.endsWith("Rory Mercury Fondo de pantalla 09.jpg")
    }

    readonly property var visualizerEffects: [
        { id: "linear", name: "Barras lineales", ready: true },
        { id: "radial", name: "Espectro radial", ready: true },
        { id: "fluid-circle", name: "Onda circular fluida", ready: false },
        { id: "energy-pulse", name: "Pulso de energía", ready: false },
        { id: "thorn-crown", name: "Corona de espinas", ready: false },
        { id: "particle-orbit", name: "Órbita de partículas", ready: false },
        { id: "double-spectrum", name: "Doble espectro", ready: false },
        { id: "blood-petals", name: "Pétalos de sangre", ready: false },
        { id: "crimson-heartbeat", name: "Latido carmesí", ready: false },
        { id: "dark-flames", name: "Llamas oscuras", ready: false },
        { id: "broken-ring", name: "Anillo fragmentado", ready: false },
        { id: "eclipse", name: "Eclipse", ready: false }
    ]

    Process {
        id: cava
        command: ["cava", "-p", Qt.resolvedUrl("assets/cava-rory.conf").toString().replace("file://", "")]
        running: root.visualizerAudioActive
        stdout: SplitParser {
            onRead: line => {
                const values = line.trim().split(";").map(value => Number(value))
                if (root.visualizerAudioActive && values.length >= 8 && values.every(value => Number.isFinite(value))) {
                    root.spectrum = values
                    root.visualizerStatus = "Audio PipeWire activo"
                }
            }
        }
        stderr: StdioCollector { id: cavaErrors }
        onExited: code => {
            if (root.effectiveVisualizerEnabled && code !== 0)
                root.visualizerStatus = cavaErrors.text.trim() || "CAVA no pudo iniciar la captura de PipeWire."
        }
    }

    // The new keys have their own Settings object so older keys are read
    // before any missing defaults can cause a write of the older properties.
    Settings {
        id: silencePreferences
        location: root.storagePath
        category: "RoryWallpaper"
        property bool visualizerHideSilentBars: false
        property real visualizerSilenceThreshold: 0.5
        property int visualizerSilenceHold: 600
        property int visualizerSilenceFade: 250
    }
    Settings {
        id: linearPreferences
        location: root.storagePath
        category: "RoryVisualizerLinear"
        property string data: root.linearDefaults
    }
    Settings {
        id: saved
        location: root.storagePath
        category: "RoryWallpaper"
        property string imageUrl: ""
        property string fitMode: "fill"
        property real dim: 0
        property string galleryFolder: ""
        property bool visualizerEnabled: false
        property string visualizerEffect: "radial"
        property real visualizerIntensity: 55
        property string visualizerColor: "#e73858"
        property real visualizerSensitivity: 100
        property bool visualizerTestMode: true
        property int visualizerBarCount: 192
        property real visualizerBarLength: 52
        property real visualizerBarThickness: 5
        property real visualizerBarGap: 3
        property real visualizerCenterX: 976
        property real visualizerCenterY: 541
        property real visualizerWidth: 584
        property real visualizerHeight: 550
        property real visualizerRadiusX: 292
        property real visualizerRadiusY: 275
        // Empty means use the linked ellipse as the independent-mode starting shape.
        // Otherwise this is JSON containing eight normalized [x,y] positions relative to the radii.
        property string visualizerShapeMode: "linked"
        property string visualizerIndependentVertices: ""
        // Geometry and per-shape control points are persisted independently of the legacy ellipse field.
        property string visualizerGeometry: "ellipse"
        property string visualizerShapeData: "{}"
        property real visualizerScale: 1
        property real visualizerOffset: 0
        property real visualizerOrientation: 0
        property real visualizerOpacity: 94
        property real visualizerGlow: 5
        property bool visualizerGlowEnabled: true
        property real visualizerGlowIntensity: 42
        property real visualizerGlowSensitivity: 100
        property real visualizerGlowSmoothing: 62
        property real visualizerSmoothing: 62
        property real visualizerAttack: 46
        property real visualizerBass: 55
        property string visualizerProfile1: ""
        property string visualizerProfile2: ""
        property string visualizerProfile3: ""
        property real visualizerEditorX: -1
        property real visualizerEditorY: -1
        property real visualizerEditorWidth: 780
        property real visualizerEditorHeight: 680
        property string visualizerEditorCategory: "General"
        property bool visualizerEditorCollapsed: false
    }
}
