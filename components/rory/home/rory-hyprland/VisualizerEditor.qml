pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "IndependentCurve.js" as IndependentCurve
import "GeometryEngine.js" as Geometry
import "AudioLayers.js" as AudioLayers

PanelWindow {
    id: editor
    property var studio: null
    required property ShellScreen modelData
    required property WallpaperSettings settings
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    visible: editor.settings.visualizerEditorOpen && modelData === (editor.studio?.targetScreen || Quickshell.screens[0])
    color: "transparent"
    WlrLayershell.namespace: "rory-audio-visualizer-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: card
        // Popup.Item menus may extend beyond the editor card. Accept their input
        // only while the overlay is visible; the idle desktop mask stays narrow.
        Region { item: card.Overlay.overlay && card.Overlay.overlay.visible ? card.Overlay.overlay : null }
        Region {
            x: editor.editBoundsX - 20
            y: editor.editBoundsY - 20
            width: editor.pointerEditActive ? editor.editBoundsWidth + 40 : 0
            height: editor.pointerEditActive ? editor.editBoundsHeight + 40 : 0
        }
        Region { item: lineGrip.visible ? lineGrip : null }
        Region { item: pointerEditOverlay.visible ? dimensionGrip : null }
    }

    property real restoredCardX: -1
    property real restoredCardY: -1
    readonly property var categoryNames: studio ? ["Composición", "Audio global"] : ["Composición", "Fondos y vínculos", "Audio global"]
    readonly property var geometryChoices: [
        { id: "circle", label: "Círculo" }, { id: "ellipse", label: "Elipse" },
        { id: "square", label: "Cuadrado" }, { id: "triangle", label: "Triángulo" },
        { id: "star", label: "Estrella" }, { id: "wave", label: "Onda libre" }
    ]
    readonly property int geometryIndex: Math.max(0,
        geometryChoices.findIndex(choice => choice.id === settings.visualizerGeometry))
    readonly property int categoryIndex: {
        const category = settings.visualizerEditorCategory
        if (category === "Audio") return categoryNames.indexOf("Audio global")
        if (category === "Perfiles") return Math.max(0, categoryNames.indexOf("Fondos y vínculos"))
        return Math.max(0, categoryNames.indexOf(category))
    }
    readonly property real wallpaperScale: settings.fitMode === "fit"
        ? Math.min(width / 1920, height / 1080)
        : settings.fitMode === "center" ? 1 : Math.max(width / 1920, height / 1080)
    readonly property real wallpaperOffsetX: (width - 1920 * wallpaperScale) / 2
    readonly property real wallpaperOffsetY: (height - 1080 * wallpaperScale) / 2
    readonly property real editCenterX: wallpaperOffsetX + settings.visualizerCenterX * wallpaperScale
    readonly property real editCenterY: wallpaperOffsetY + settings.visualizerCenterY * wallpaperScale
    readonly property real editScale: wallpaperScale * settings.visualizerScale
    readonly property int shapePointCount: IndependentCurve.controlCount(settings.visualizerGeometry,settings.visualizerShapeData)
    readonly property bool hasCustomShapePoints: (settings.visualizerShapeMode === "independent" || settings.visualizerGeometry === "wave" && IndependentCurve.hasAdvancedWave(settings.visualizerShapeData))
        && IndependentCurve.hasStoredVertices(settings.visualizerShapeData,
            settings.visualizerGeometry, settings.visualizerIndependentVertices)
    readonly property bool usesShapePath: settings.visualizerGeometry !== "circle"
        && settings.visualizerGeometry !== "ellipse" || hasCustomShapePoints
    readonly property bool usesEllipseBounds: settings.visualizerShapeMode === "linked"
        && settings.visualizerGeometry === "ellipse"
    readonly property var sourceVertexOffsets: readVertexOffsets()
    readonly property var editVertices: buildEditVertices()
    readonly property real editBoundsX: calculateBound(0)
    readonly property real editBoundsY: calculateBound(1)
    readonly property real editBoundsWidth: calculateBound(2)
    readonly property real editBoundsHeight: calculateBound(3)
    readonly property bool pointerEditActive: visible && settings.visualizerPointerEditMode
        && settings.effectiveVisualizerEnabled && settings.visualizerEffect === "radial"

    readonly property var lineFrame: settings.visualizerEffect === "linear"
        ? Geometry.linearFrame(settings.visualizerLinear,width,height) : null

    Rectangle {
        id: lineGrip
        readonly property var frame: editor.lineFrame
        visible: !!frame && editor.visible && editor.settings.visualizerPointerEditMode
            && editor.settings.effectiveVisualizerEnabled
        x: !frame ? 0 : frame.horizontal ? frame.start : Math.max(0,Math.min(editor.width-width,frame.base-width/2))
        y: !frame ? 0 : frame.horizontal ? Math.max(0,Math.min(editor.height-height,frame.base-height/2)) : frame.start
        width: !frame ? 0 : frame.horizontal ? frame.length : 16
        height: !frame ? 0 : frame.horizontal ? 16 : frame.length
        color: "#48241117"
        border.color: "#ca879b"
        radius: 3
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            property point start
            property var original
            onPressed: event => {
                start = mapToItem(null,event.x,event.y)
                original = editor.settings.visualizerLinear
                editor.beginTransaction()
            }
            onPositionChanged: event => {
                if (!pressed) return
                const frame = lineGrip.frame
                const point = mapToItem(null,event.x,event.y)
                const dx = point.x-start.x, dy = point.y-start.y
                const percent = (value,delta,space) => Math.max(0,Math.min(100,value+100*delta/Math.max(1,space)))
                const changes = {}
                if (frame.horizontal || original.edge==="free")
                    changes.x = percent(original.x,dx,frame.horizontal ? frame.along-frame.length : frame.across-frame.depth)
                if (!frame.horizontal || original.edge==="free")
                    changes.y = percent(original.y,dy,frame.horizontal ? frame.across-frame.depth : frame.along-frame.length)
                if (original.edge!=="free")
                    changes.inset = Math.max(0,Math.min(4096,frame.across-frame.depth,
                        original.inset+(frame.horizontal ? dy : dx)*(frame.reverse ? -1 : 1)))
                editor.history.editLinear(changes)
            }
            onReleased: editor.endTransaction()
            onCanceled: editor.endTransaction()
        }
    }

    property var profileManager:null
    readonly property var history:profileManager ? profileManager.controller : localHistory
    readonly property var undoStack: history.undoStack
    readonly property var redoStack: history.redoStack
    readonly property bool transactionOpen: history.transactionOpen
    readonly property var editableKeys: history.editableKeys
    property int pendingLegacyProfile:0
    property bool resetCompositionPending:false
    property int selectedProfile: 1
    property real colorHue: 0
    property real colorSaturation: 1
    property real colorValue: 1
    readonly property bool restoring: history.restoring
    readonly property var layerDocument: history.document
    readonly property string layerError: history.error || history.resolution.error
    VisualizerHistory { id: localHistory; settings: editor.settings; selectedProfile: editor.selectedProfile;initializeOnCompleted:!editor.profileManager }

    function readVertexOffsets() {
        if (hasCustomShapePoints)
            return IndependentCurve.readVertices(settings.visualizerShapeData,
                settings.visualizerGeometry, settings.visualizerIndependentVertices)
        return IndependentCurve.defaultVertices(settings.visualizerGeometry)
    }
    function buildEditVertices() {
        const points = []
        for (let i = 0; i < shapePointCount; ++i) {
            const point = IndependentCurve.controlPoint(settings.visualizerGeometry, i, sourceVertexOffsets,
                settings.visualizerEffectiveRadiusX * editScale,
                settings.visualizerEffectiveRadiusY * editScale,
                editCenterX, editCenterY, settings.visualizerOrientation)
            points.push(point.x, point.y)
        }
        return points
    }
    function calculateBound(component) {
        if (usesEllipseBounds) {
            const rx = settings.visualizerEffectiveRadiusX * editScale
            const ry = settings.visualizerEffectiveRadiusY * editScale
            if (component === 0) return editCenterX - rx
            if (component === 1) return editCenterY - ry
            if (component === 2) return 2 * rx
            return 2 * ry
        }
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
        const samplesPerEdge = 24
        for (let sample = 0; sample < shapePointCount * samplesPerEdge; ++sample) {
            const position = sample / samplesPerEdge
            const edge = Math.floor(position)
            const point = IndependentCurve.pointOnEdge(settings.visualizerGeometry, edge,
                position - edge, sourceVertexOffsets,
                settings.visualizerEffectiveRadiusX * editScale, settings.visualizerEffectiveRadiusY * editScale,
                editCenterX, editCenterY, settings.visualizerOrientation)
            minX = Math.min(minX, point.x); maxX = Math.max(maxX, point.x)
            minY = Math.min(minY, point.y); maxY = Math.max(maxY, point.y)
        }
        if (component === 0) return minX
        if (component === 1) return minY
        if (component === 2) return Math.max(1, maxX - minX)
        return Math.max(1, maxY - minY)
    }
    function handlePoint(index) {
        if (!(usesEllipseBounds))
            return [editVertices[2 * index], editVertices[2 * index + 1]]
        const xf = [0, 0.5, 1, 1, 1, 0.5, 0, 0]
        const yf = [0, 0, 0, 0.5, 1, 1, 1, 0.5]
        return [editBoundsX + xf[index] * editBoundsWidth,
                editBoundsY + yf[index] * editBoundsHeight]
    }

    function selectGeometry(shape) {
        if (settings.visualizerGeometry === shape) return
        beginTransaction()
        setValue("visualizerGeometry", shape)
        endTransaction()
    }

    function readValue(key) { return history.readValue(key) }
    function snapshot() { return history.snapshot() }
    function setInputPending(source,pending){if(history)history.setInputPending(source,pending)}
    function finishPendingInputs(){history.finishPendingInputs()}
    function closeEditor() {
        finishPendingInputs()
        settings.visualizerPointerEditMode = false
        settings.visualizerEditorOpen = false
    }

    function beginTransaction() { history.beginTransaction() }
    function endTransaction() { history.endTransaction() }
    function setValue(key,value) { history.setValue(key,value) }
    function applySnapshot(value) { history.applySnapshot(value) }
    function textInputHasFocus(item){return item && typeof item.selectAll==="function"}
    function undo() { history.undo() }
    function redo() { history.redo() }
    function requestLegacyProfile(index){
        finishPendingInputs();endTransaction()
        if(index!==selectedProfile)pendingLegacyProfile=index
        legacyPicker.currentIndex=Qt.binding(()=>editor.selectedProfile-1)
    }
    function resolveLegacyProfile(choice){
        if(choice==="cancel"){pendingLegacyProfile=0;return}
        if(!pendingLegacyProfile)return
        if(choice==="save"){history.saveProfile();if(history.error)return}
        const previous=selectedProfile;selectedProfile=pendingLegacyProfile;history.loadProfile()
        if(history.error){selectedProfile=previous;return}
        pendingLegacyProfile=0
    }
    function saveProfile() {if(profileManager){profileManager.saveProfile(profileManager.activeId,false)}else history.saveProfile()}
    function loadProfile() {if(profileManager){profileManager.requestLoad(profileManager.selectedId,"manual","")}else history.loadProfile()}
    function editCommon(id,key,value) { history.editCommon(id,key,value) }
    function editParam(id,type,key,value) { history.editParam(id,type,key,value) }
    function setLayerType(id,type) { history.setLayerType(id,type) }
    function setLayerEnabled(id,enabled) { history.setLayerEnabled(id,enabled) }
    function addLayer(sourceId) { return history.addLayer(sourceId) }
    function removeLayer(id) { history.removeLayer(id) }
    function moveLayer(id,delta) { history.moveLayer(id,delta) }
    function resetLayer(id) { history.resetLayer(id) }
    function hexByte(value) {
        const text=Math.round(value).toString(16)
        return text.length<2 ? "0"+text : text
    }
    function restoreDefaults() {
        const values = ({
            visualizerBarCount: 192, visualizerBarLength: 52, visualizerBarThickness: 5,
            visualizerBarGap: 3, visualizerCenterX: 976, visualizerCenterY: 541,
            visualizerWidth: 584, visualizerHeight: 550,
            visualizerRadiusX: 292, visualizerRadiusY: 275, visualizerOrientation: 0,
            visualizerShapeMode: "linked", visualizerIndependentVertices: "",
            visualizerGeometry: "ellipse", visualizerShapeData: "{}",
            visualizerIntensity: 55, visualizerSensitivity: 100, visualizerOpacity: 94,
            visualizerGlow: 5, visualizerGlowEnabled: true, visualizerGlowIntensity: 42,
            visualizerGlowSensitivity: 100, visualizerGlowSmoothing: 62,
            visualizerSmoothing: 62, visualizerAttack: 46,
            visualizerBass: 55, visualizerColor: "#e73858",
            visualizerScale: 1, visualizerOffset: 0
        })
        values.visualizerLayersV2=JSON.stringify(AudioLayers.migrate(values,"",""))
        history.record();applySnapshot(values)
    }
    function syncHsvFromColor(value) {
        const match = /^#?([0-9a-fA-F]{6})$/.exec(String(value))
        if (!match) return
        const hex = match[1]
        const r = parseInt(hex.slice(0, 2), 16) / 255
        const g = parseInt(hex.slice(2, 4), 16) / 255
        const b = parseInt(hex.slice(4, 6), 16) / 255
        const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min
        let h = 0
        if (delta !== 0) {
            if (max === r) h = 60 * (((g - b) / delta) % 6)
            else if (max === g) h = 60 * ((b - r) / delta + 2)
            else h = 60 * ((r - g) / delta + 4)
        }
        colorHue = (h + 360) % 360
        colorSaturation = max === 0 ? 0 : delta / max
        colorValue = max
    }
    function colorFromHsv() {
        const h = ((colorHue % 360) + 360) % 360 / 60
        const s = Math.max(0, Math.min(1, colorSaturation))
        const v = Math.max(0, Math.min(1, colorValue))
        const c = v * s
        const x = c * (1 - Math.abs(h % 2 - 1))
        const m = v - c
        let rgb
        if (h < 1) rgb = [c, x, 0]
        else if (h < 2) rgb = [x, c, 0]
        else if (h < 3) rgb = [0, c, x]
        else if (h < 4) rgb = [0, x, c]
        else if (h < 5) rgb = [x, 0, c]
        else rgb = [c, 0, x]
        const hex = rgb.map(component => hexByte((component + m) * 255)).join("")
        setValue("visualizerColor", "#" + hex)
    }
    function applyColorInput(input) {
        const text = String(input).trim()
        let hex = /^#?([0-9a-fA-F]{6})$/.exec(text)
        if (hex) {
            setValue("visualizerColor", "#" + hex[1].toLowerCase())
            return true
        }
        const rgb = /^(?:rgb\s*\(\s*)?(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*\)?$/i.exec(text)
        if (!rgb) return false
        const channels = rgb.slice(1).map(Number)
        if (channels.some(channel => channel < 0 || channel > 255)) return false
        setValue("visualizerColor", "#" + channels.map(channel => hexByte(channel)).join(""))
        return true
    }

    function restoreWindowPosition() {
        if (!visible && restoredCardX < 0) return
        const maxX = Math.max(12, width - card.width - 12)
        const maxY = Math.max(12, height - card.height - 12)
        if (settings.visualizerEditorX < 0 || settings.visualizerEditorY < 0) {
            restoredCardX = Math.max(12, (width - card.width) / 2)
            restoredCardY = Math.max(12, (height - card.height) / 2)
        } else {
            restoredCardX = Math.max(12, Math.min(maxX, settings.visualizerEditorX))
            restoredCardY = Math.max(12, Math.min(maxY, settings.visualizerEditorY))
        }
        card.x = restoredCardX
        card.y = restoredCardY
        settings.visualizerEditorX = restoredCardX
        settings.visualizerEditorY = restoredCardY
    }
    function persistWindowPosition() {
        const maxX = Math.max(12, width - card.width - 12)
        const maxY = Math.max(12, height - card.height - 12)
        restoredCardX = Math.max(12, Math.min(maxX, card.x))
        restoredCardY = Math.max(12, Math.min(maxY, card.y))
        card.x = restoredCardX
        card.y = restoredCardY
        settings.visualizerEditorX = restoredCardX
        settings.visualizerEditorY = restoredCardY
    }
    function resetWindowPosition() {
        settings.visualizerEditorX = -1
        settings.visualizerEditorY = -1
        restoreWindowPosition()
        persistWindowPosition()
    }

    function resizeEditor(deltaX, deltaY) {
        settings.visualizerEditorWidth = Math.max(360,
            Math.min(width - 24, settings.visualizerEditorWidth + deltaX))
        settings.visualizerEditorHeight = Math.max(300,
            Math.min(height - 24, settings.visualizerEditorHeight + deltaY))
    }

    Component.onCompleted: {
        syncHsvFromColor(readValue("visualizerColor"))
        Qt.callLater(restoreWindowPosition)
    }
    onVisibleChanged: {
        if (visible) Qt.callLater(restoreWindowPosition)
        else {
            endTransaction()
        }
    }
    onLayerDocumentChanged: if (layerDocument) syncHsvFromColor(readValue("visualizerColor"))
    onPointerEditActiveChanged: {if(!pointerEditActive)endTransaction();else layersPanel.sharedSelected=true}
    onWidthChanged: if (visible) Qt.callLater(restoreWindowPosition)
    onHeightChanged: if (visible) Qt.callLater(restoreWindowPosition)

    Rectangle {
        id: card
        width: Math.max(1, Math.min(Math.max(360, editor.settings.visualizerEditorWidth), editor.width - 24))
        height: editor.settings.visualizerEditorCollapsed ? 60 : Math.max(1, Math.min(Math.max(300, editor.settings.visualizerEditorHeight), editor.height - 24))
        onWidthChanged: if (editor.visible) Qt.callLater(editor.restoreWindowPosition)
        onHeightChanged: if (editor.visible) Qt.callLater(editor.restoreWindowPosition)
        radius: 10; color: "#f51c191e"; border.color: "#6b3e4d"; border.width: 1
        z: 2

        ColumnLayout {
            anchors.fill:parent;anchors.margins:12;spacing:8
            RowLayout {
                Layout.fillWidth:true;Layout.preferredHeight:34;spacing:5
                Label {Layout.fillWidth:true;Layout.minimumWidth:0;text:"Rory Desktop Studio";color:"#f0e6eb";font.pixelSize:16;font.bold:true;elide:Text.ElideRight}
                StudioToolButton {objectName:"undoAction";text:"↶";Accessible.name:"Deshacer";ToolTip.visible:hovered;ToolTip.text:"Deshacer · Ctrl+Z";enabled:editor.undoStack.length>0;onClicked:{card.forceActiveFocus();editor.undo()}}
                StudioToolButton {objectName:"redoAction";text:"↷";Accessible.name:"Rehacer";ToolTip.visible:hovered;ToolTip.text:"Rehacer · Ctrl+Shift+Z";enabled:editor.redoStack.length>0;onClicked:{card.forceActiveFocus();editor.redo()}}
                StudioToolButton {text:"⋯";Accessible.name:"Opciones de composición y ventana";onClicked:windowMenu.popup()}
                StudioToolButton {text:editor.settings.visualizerEditorCollapsed ? "▣" : "—";Accessible.name:"Contraer o expandir";onClicked:editor.settings.visualizerEditorCollapsed=!editor.settings.visualizerEditorCollapsed}
                StudioToolButton {text:"×";Accessible.name:"Cerrar editor";onClicked:editor.closeEditor()}
            }
            StudioNavigation {Layout.fillWidth:true;visible:!editor.settings.visualizerEditorCollapsed && editor.studio!==null;studio:editor.studio;targetScreen:editor.modelData;destination:"audio"}
            Loader {Layout.fillWidth:true;visible:!editor.settings.visualizerEditorCollapsed;active:editor.profileManager!==null;sourceComponent:Component {StudioProfileBar {manager:editor.profileManager}}}
            RowLayout {visible:!editor.settings.visualizerEditorCollapsed && editor.profileManager===null;Layout.fillWidth:true
                StudioCombo {id:legacyPicker;Layout.fillWidth:true;model:["Perfil anterior 1","Perfil anterior 2","Perfil anterior 3"];currentIndex:editor.selectedProfile-1;onActivated:index=>editor.requestLegacyProfile(index+1)}
                StudioToolButton {
                    text:"⋯";Accessible.name:"Opciones del perfil anterior"
                    onClicked:legacyProfileMenu.popup()
                    StudioMenu {
                        id:legacyProfileMenu
                        StudioMenuItem {text:"Guardar";onTriggered:editor.saveProfile()}
                    }
                }
            }
            Item {objectName:"categoryNavigation";Layout.fillWidth:true;implicitHeight:36;visible:!editor.settings.visualizerEditorCollapsed
                RowLayout {anchors.fill:parent;visible:parent.width>=550;spacing:6
                    Repeater {model:editor.categoryNames;delegate:StudioButton {required property string modelData;objectName:"category_"+modelData;Layout.fillWidth:true;Layout.minimumWidth:0;text:modelData;checkable:true;checked:editor.categoryNames[editor.categoryIndex]===modelData;onClicked:{card.forceActiveFocus();editor.endTransaction();editor.settings.visualizerEditorCategory=modelData;editor.settings.visualizerPointerEditMode=false}}}
                }
                StudioCombo {anchors.fill:parent;visible:parent.width<550;objectName:"workspaceSelector";model:editor.categoryNames;currentIndex:editor.categoryIndex;onActivated:index=>{card.forceActiveFocus();editor.endTransaction();editor.settings.visualizerEditorCategory=editor.categoryNames[index];editor.settings.visualizerPointerEditMode=false}}
            }
            ScrollView {
                id:categoryContent;objectName:"categoryContent";visible:!editor.settings.visualizerEditorCollapsed
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ColumnLayout {
                    width:categoryContent.availableWidth;spacing:14
                    Loader {Layout.fillWidth:true;active:editor.profileManager!==null;sourceComponent:Component {StudioProfileNotice {manager:editor.profileManager}}}
                    ColumnLayout {Layout.fillWidth:true;visible:editor.profileManager===null && editor.pendingLegacyProfile>0
                        Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e6b0c3";text:"Modo anterior: ¿cómo cambiar al perfil "+editor.pendingLegacyProfile+"? La composición actual no se reemplaza sin confirmación."}
                        Flow {Layout.fillWidth:true;spacing:6;StudioButton {text:"Guardar y cambiar";onClicked:editor.resolveLegacyProfile("save")}StudioButton {text:"Descartar y cambiar";onClicked:editor.resolveLegacyProfile("discard")}StudioButton {text:"Cancelar";onClicked:editor.resolveLegacyProfile("cancel")}}
                    }
                    Label {visible:editor.layerError!=="";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e6b0c3";text:editor.layerError}
                    ColumnLayout {Layout.fillWidth:true;visible:editor.resetCompositionPending
                        Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e6b0c3";text:"¿Restablecer toda la composición? Se sustituirán capas, figuras, recortes y efectos por una sola capa inicial. Los perfiles guardados se conservan; puedes deshacer."}
                        Flow {Layout.fillWidth:true;spacing:6;StudioButton {text:"Restablecer composición";onClicked:{editor.restoreDefaults();editor.resetCompositionPending=false}}StudioButton {text:"Cancelar";onClicked:editor.resetCompositionPending=false}}
                    }
                    AudioLayersPanel {id:layersPanel;objectName:"studioLayers";Layout.fillWidth:true;visible:editor.categoryIndex===0;controller:editor.history;settings:editor.settings}
                    ColumnLayout {Layout.fillWidth:true;visible:editor.categoryNames[editor.categoryIndex]==="Fondos y vínculos"
                        Label {Layout.fillWidth:true;text:"Fondos y vínculos";font.pixelSize:19;font.bold:true;color:"#eadce5"}
                        Loader {Layout.fillWidth:true;active:editor.studio===null && editor.profileManager!==null;sourceComponent:Component {
                            ColumnLayout {
                                Loader {Layout.fillWidth:true;active:editor.profileManager.associationManager!==null;sourceComponent:StudioWallpaperWorkspace {settings:editor.settings;manager:editor.profileManager.associationManager}}
                                Loader {Layout.fillWidth:true;active:editor.profileManager.associationManager===null;sourceComponent:ProfileManagerPanel {manager:editor.profileManager}}
                            }
                        }}
                    }
                    StudioAudioPanel {Layout.fillWidth:true;visible:editor.categoryNames[editor.categoryIndex]==="Audio global";controller:editor.history;settings:editor.settings}
                }
            }
        }
        StudioMenu {id:windowMenu
            StudioMenuItem {text:"Recuperar posición de la ventana";onTriggered:editor.resetWindowPosition()}
            StudioMenuItem {text:"Restablecer composición…";onTriggered:editor.resetCompositionPending=true}
        }

        MouseArea {
            x: 18; y: 8; width: Math.max(40, card.width - 250); height: 42
            z: 2; acceptedButtons: Qt.LeftButton; cursorShape: Qt.SizeAllCursor
            drag.target: card; drag.axis: Drag.XAndYAxis
            drag.minimumX: 12; drag.maximumX: Math.max(12, editor.width - card.width - 12)
            drag.minimumY: 12; drag.maximumY: Math.max(12, editor.height - card.height - 12)
            onReleased: editor.persistWindowPosition()
        }
        MouseArea {
            width: 24; height: 24; anchors.right: parent.right; anchors.bottom: parent.bottom
            visible: !editor.settings.visualizerEditorCollapsed
            z: 4; acceptedButtons: Qt.LeftButton; cursorShape: Qt.SizeFDiagCursor
            property real startX: 0
            property real startY: 0
            onPressed: mouse => {
                const point = mapToItem(pointerEditOverlay, mouse.x, mouse.y)
                startX = point.x; startY = point.y
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                const point = mapToItem(pointerEditOverlay, mouse.x, mouse.y)
                editor.resizeEditor(point.x - startX, point.y - startY)
                startX = point.x; startY = point.y
            }
            onReleased: editor.persistWindowPosition()
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 12; height: 12; color: "transparent"; border.color: "#e73858"; opacity: 0.8 }
        }
    }

    Item {
        id: pointerEditOverlay
        anchors.fill: parent
        visible: editor.pointerEditActive
        z: 1

        Canvas {
            id: editOutline
            x: editor.editBoundsX
            y: editor.editBoundsY
            width: editor.editBoundsWidth
            height: editor.editBoundsHeight
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (width < 2 || height < 2) return
                ctx.save()
                ctx.strokeStyle = "#ca879b"
                ctx.lineWidth = 1.5
                ctx.setLineDash([6, 4])
                ctx.beginPath()
                if (editor.usesShapePath) {
                    const samplesPerEdge = 32
                    for (let sample = 0; sample <= editor.shapePointCount * samplesPerEdge; ++sample) {
                        const position = sample / samplesPerEdge
                        const edge = Math.min(editor.shapePointCount - 1, Math.floor(position))
                        const fraction = sample === editor.shapePointCount * samplesPerEdge ? 1 : position - edge
                        const point = IndependentCurve.pointOnEdge(editor.settings.visualizerGeometry,
                            edge, fraction,
                            editor.sourceVertexOffsets,
                            editor.settings.visualizerEffectiveRadiusX * editor.editScale,
                            editor.settings.visualizerEffectiveRadiusY * editor.editScale,
                            editor.editCenterX, editor.editCenterY,
                            editor.settings.visualizerOrientation)
                        if (sample === 0)
                            ctx.moveTo(point.x - editOutline.x, point.y - editOutline.y)
                        else
                            ctx.lineTo(point.x - editOutline.x, point.y - editOutline.y)
                    }
                    ctx.closePath()
                } else {
                    // Context2D ellipse() takes the bounding rectangle, not center/radii.
                    // Use the whole Canvas bounds so the guide remains centered on the spectrum.
                    ctx.ellipse(1, 1, width - 2, height - 2)
                }
                ctx.stroke()
                ctx.setLineDash([])
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(editor.editCenterX - x - 7, editor.editCenterY - y)
                ctx.lineTo(editor.editCenterX - x + 7, editor.editCenterY - y)
                ctx.moveTo(editor.editCenterX - x, editor.editCenterY - y - 7)
                ctx.lineTo(editor.editCenterX - x, editor.editCenterY - y + 7)
                ctx.stroke()
                ctx.restore()
            }
            Connections {
                target: editor.settings
                function onVisualizerCenterXChanged() { editOutline.requestPaint() }
                function onVisualizerCenterYChanged() { editOutline.requestPaint() }
                function onVisualizerWidthChanged() { editOutline.requestPaint() }
                function onVisualizerHeightChanged() { editOutline.requestPaint() }
                function onVisualizerRadiusXChanged() { editOutline.requestPaint() }
                function onVisualizerRadiusYChanged() { editOutline.requestPaint() }
                function onVisualizerScaleChanged() { editOutline.requestPaint() }
                function onVisualizerBarLengthChanged() { editOutline.requestPaint() }
                function onVisualizerOffsetChanged() { editOutline.requestPaint() }
                function onVisualizerGlowChanged() { editOutline.requestPaint() }
                function onVisualizerShapeModeChanged() { editOutline.requestPaint() }
                function onVisualizerIndependentVerticesChanged() { editOutline.requestPaint() }
                function onVisualizerOrientationChanged() { editOutline.requestPaint() }
                function onVisualizerGeometryChanged() { editOutline.requestPaint() }
                function onVisualizerShapeDataChanged() { editOutline.requestPaint() }
            }
        }

        Repeater {
            model: editor.shapePointCount
            delegate: Rectangle {
                required property int index
                x: editor.handlePoint(index)[0] - width / 2
                y: editor.handlePoint(index)[1] - height / 2
                width: pointerEditMouse.activeHandle === index ? 30 : 26
                height: width
                radius: index % 2 === 1 ? width / 2 : 3
                color: pointerEditMouse.activeHandle === index ? "#ff4268" : "#241117"
                border.color: pointerEditMouse.activeHandle === index ? "#fff0f3" : "#ca879b"
                border.width: pointerEditMouse.activeHandle === index ? 3 : 2
                z: 2
                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "#fff0f3" }
            }
        }

        Rectangle {
            id: dimensionGrip
            x: editor.editBoundsX + editor.editBoundsWidth + 18
            y: editor.editBoundsY + editor.editBoundsHeight + 18
            width: 28; height: 28; radius: 5
            color: "#241117"; border.color: "#ca879b"
            Text { anchors.centerIn: parent; text: "↘"; color: "#f0e6eb"; font.pixelSize: 20 }
        }

        MouseArea {
            id: pointerEditMouse
            x: editor.editBoundsX - 20
            y: editor.editBoundsY - 20
            width: editor.editBoundsWidth + 66
            height: editor.editBoundsHeight + 66
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: controllerCursor(controllerAt(mouseX, mouseY))
            property string dragKind: ""
            property real pressX: 0
            property real pressY: 0
            property real startCenterX: 0
            property real startCenterY: 0
            property real startRadiusX: 1
            property real startRadiusY: 1
            property real startWidth: 0
            property real startHeight: 0
            property real startOrientation: 0
            property real startPointerAngle: 0
            property int activeHandle: -1
            property var startVertices: []

            function controllerAt(x, y) {
                if (x >= dimensionGrip.x - pointerEditMouse.x && y >= dimensionGrip.y - pointerEditMouse.y)
                    return "dimensions"
                const controllers = []
                for (let i = 0; i < editor.shapePointCount; ++i) {
                    const p = editor.handlePoint(i)
                    controllers.push({ kind: "handle-" + i,
                        x: p[0] - editor.editBoundsX + 20,
                        y: p[1] - editor.editBoundsY + 20 })
                }
                let closest = "move"
                let nearestDistance = 29 * 29
                for (const controller of controllers) {
                    const dx = x - controller.x
                    const dy = y - controller.y
                    const distance = dx * dx + dy * dy
                    if (distance <= nearestDistance) {
                        closest = controller.kind
                        nearestDistance = distance
                    }
                }
                return closest
            }
            function controllerCursor(kind) {
                if (kind === "move") return Qt.SizeAllCursor
                if (kind === "dimensions") return Qt.SizeFDiagCursor
                if (kind.indexOf("handle-") === 0) return Qt.CrossCursor
                if (kind === "left" || kind === "right") return Qt.SizeHorCursor
                if (kind === "top" || kind === "bottom") return Qt.SizeVerCursor
                return kind === "top-left" || kind === "bottom-right"
                    ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            }
            onPressed: mouse => {
                editor.beginTransaction()
                const point = mapToItem(pointerEditOverlay, mouse.x, mouse.y)
                pressX = point.x
                pressY = point.y
                startCenterX = editor.settings.visualizerCenterX
                startCenterY = editor.settings.visualizerCenterY
                startRadiusX = editor.settings.visualizerRadiusX
                startRadiusY = editor.settings.visualizerRadiusY
                startWidth = editor.settings.visualizerWidth
                startHeight = editor.settings.visualizerHeight
                startOrientation = editor.settings.visualizerOrientation
                startPointerAngle = Math.atan2(point.y - editor.editCenterY, point.x - editor.editCenterX)
                startVertices = editor.sourceVertexOffsets.slice()
                dragKind = controllerAt(mouse.x, mouse.y)
                if (dragKind === "move" && (mouse.modifiers & Qt.ShiftModifier))
                    dragKind = "rotate"
                const handleIndex = dragKind.indexOf("handle-") === 0 ? Number(dragKind.slice(7)) : -1
                activeHandle = handleIndex
                if(handleIndex>=0){layersPanel.sharedPointSelection=handleIndex;layersPanel.sharedPointsVisible=true}
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                const point = mapToItem(pointerEditOverlay, mouse.x, mouse.y)
                const dx = point.x - pressX
                const dy = point.y - pressY
                if (dragKind === "rotate") {
                    const pointerAngle = Math.atan2(point.y - editor.editCenterY, point.x - editor.editCenterX)
                    const delta = (pointerAngle - startPointerAngle) * 180 / Math.PI
                    editor.setValue("visualizerOrientation", Math.max(-180, Math.min(180,
                        startOrientation + delta)))
                } else if (dragKind === "move") {
                    editor.history.moveSharedGeometry(startCenterX, startCenterY, dx, dy, editor.wallpaperScale)
                } else if (dragKind === "dimensions") {
                    editor.history.resizeSharedGeometry(startWidth, startHeight, dx, dy, editor.wallpaperScale)
                } else if (dragKind.indexOf("handle-") === 0
                           && editor.settings.visualizerShapeMode === "independent") {
                    const index = Number(dragKind.slice(7))
                    const angle = editor.settings.visualizerOrientation * Math.PI / 180
                    const cos = Math.cos(angle), sin = Math.sin(angle)
                    const localDx = (dx * cos + dy * sin)
                        / Math.max(1, editor.settings.visualizerEffectiveRadiusX * editor.editScale)
                    const localDy = (-dx * sin + dy * cos)
                        / Math.max(1, editor.settings.visualizerEffectiveRadiusY * editor.editScale)
                    const next = startVertices.slice()
                    next[2 * index] = startVertices[2 * index] + localDx
                    next[2 * index + 1] = startVertices[2 * index + 1] + localDy
                    editor.setValue("visualizerShapeData", IndependentCurve.writeVertices(
                        editor.settings.visualizerShapeData, editor.settings.visualizerGeometry, next))
                    if (editor.settings.visualizerGeometry === "ellipse")
                        editor.setValue("visualizerIndependentVertices", JSON.stringify(next))
                } else if (dragKind.indexOf("handle-") === 0) {
                    const handleIndex = Number(dragKind.slice(7))
                    const shape = editor.settings.visualizerGeometry
                    if (shape === "ellipse") {
                        const kind = ["top-left", "top", "top-right", "right", "bottom-right", "bottom", "bottom-left", "left"][handleIndex]
                        const changesX = kind !== "top" && kind !== "bottom"
                        const changesY = kind !== "left" && kind !== "right"
                        const signX = kind.indexOf("left") >= 0 ? -1 : 1
                        const signY = kind.indexOf("top") >= 0 ? -1 : 1
                        if (changesX) editor.setValue("visualizerRadiusX", Math.max(60, Math.min(700,
                            startRadiusX + signX * dx / (editor.editScale * editor.settings.visualizerWidth / 584))))
                        if (changesY) editor.setValue("visualizerRadiusY", Math.max(60, Math.min(500,
                            startRadiusY + signY * dy / (editor.editScale * editor.settings.visualizerHeight / 550))))
                    } else {
                        const base = IndependentCurve.defaultVertices(shape)
                        const baseX = base[2 * handleIndex]
                        const baseY = base[2 * handleIndex + 1]
                        const angle = startOrientation * Math.PI / 180
                        const sourceDx = (dx * Math.cos(angle) + dy * Math.sin(angle)) / (editor.editScale * editor.settings.visualizerWidth / 584)
                        const sourceDy = (-dx * Math.sin(angle) + dy * Math.cos(angle)) / (editor.editScale * editor.settings.visualizerHeight / 550)
                        if (Math.abs(baseX) > 0.0001)
                            editor.setValue("visualizerRadiusX", Math.max(60, Math.min(700,
                                startRadiusX + Math.sign(baseX) * sourceDx)))
                        if (Math.abs(baseY) > 0.0001)
                            editor.setValue("visualizerRadiusY", Math.max(60, Math.min(700,
                                startRadiusY + Math.sign(baseY) * sourceDy)))
                    }
                } else {
                    const changesX = dragKind !== "top" && dragKind !== "bottom"
                    const changesY = dragKind !== "left" && dragKind !== "right"
                    const signX = dragKind.indexOf("left") >= 0 ? -1 : 1
                    const signY = dragKind.indexOf("top") >= 0 ? -1 : 1
                    const sourceDeltaX = dx / (editor.editScale * editor.settings.visualizerWidth / 584)
                    const sourceDeltaY = dy / (editor.editScale * editor.settings.visualizerHeight / 550)
                    if (changesX)
                        editor.setValue("visualizerRadiusX", Math.max(60, Math.min(700,
                            startRadiusX + signX * sourceDeltaX)))
                    if (changesY)
                        editor.setValue("visualizerRadiusY", Math.max(60, Math.min(500,
                            startRadiusY + signY * sourceDeltaY)))
                }
            }
            onReleased: { dragKind = ""; activeHandle = -1; editor.endTransaction() }
            onCanceled: { dragKind = ""; activeHandle = -1; editor.endTransaction() }
        }
    }

    Shortcut {sequences:[StandardKey.Undo];context:Qt.WindowShortcut;enabled:editor.visible && !editor.textInputHasFocus(card.Window.window ? card.Window.window.activeFocusItem : null);onActivated:editor.undo()}
    Shortcut {sequence:"Ctrl+Shift+Z";context:Qt.WindowShortcut;enabled:editor.visible && !editor.textInputHasFocus(card.Window.window ? card.Window.window.activeFocusItem : null);onActivated:editor.redo()}
    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; enabled:!editor.textInputHasFocus(card.Window.window ? card.Window.window.activeFocusItem : null); onActivated: editor.closeEditor() }
}
