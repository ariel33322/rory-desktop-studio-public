pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import "WallpaperIdentity.js" as Wallpaper

Item {
    id: root
    // The shell supplies a real path before constructing Settings, bypassing versioned QML VFS snapshots.
    required property url storagePath
    visible: false
    width: 0
    height: 0
    property bool editorOpen: false
    property bool pointerEditMode: false
    property var editorScreen: null

    readonly property int widgetWidth: saved.customWidth > 0 ? saved.customWidth : Math.round(timeSize * 5)
    readonly property int widgetHeight: saved.customHeight > 0 ? saved.customHeight : timeSize + 160
    property alias customWidth: saved.customWidth
    property alias customHeight: saved.customHeight
    property alias fontFamily: saved.fontFamily
    property alias fontWeight: saved.fontWeight
    property alias clockRotation: saved.clockRotation
    property alias showSeconds: saved.showSeconds
    property alias showDate: saved.showDate
    property alias elementSpacing: saved.elementSpacing
    property alias horizontalAlignment: saved.horizontalAlignment
    property alias verticalAlignment: saved.verticalAlignment
    property alias backgroundEnabled: saved.backgroundEnabled
    property alias backgroundColor: saved.backgroundColor
    property alias backgroundOpacity: saved.backgroundOpacity
    property alias backgroundRadius: saved.backgroundRadius
    property alias backgroundImage: saved.backgroundImage
    readonly property string backgroundImageUrl: {
        try { return Wallpaper.normalize(backgroundImage) }
        catch (_) { return backgroundImage }
    }
    property alias backgroundX: saved.backgroundX
    property alias backgroundY: saved.backgroundY
    property alias backgroundWidth: saved.backgroundWidth
    property alias backgroundHeight: saved.backgroundHeight
    property alias backgroundScale: saved.backgroundScale
    property alias backgroundRotation: saved.backgroundRotation
    property alias backgroundFit: saved.backgroundFit
    property alias profilesData: saved.profilesData
    // An empty color retains the original color of each glyph group.
    readonly property var outlineDefaults: ({outlineEnabled:true, outlineColor:"", outlineOpacity:1, outlineWidth:1})
    property alias outlineEnabled: outline.outlineEnabled
    property alias outlineColor: outline.outlineColor
    property alias outlineOpacity: outline.outlineOpacity
    property alias outlineWidth: outline.outlineWidth
    readonly property var editableKeys: ["timeSize", "accent", "textColor", "title", "signature", "widgetOpacity", "leftPercent", "topPercent", "use24Hour", "customWidth", "customHeight", "fontFamily", "fontWeight", "clockRotation", "showSeconds", "showDate", "elementSpacing", "horizontalAlignment", "verticalAlignment", "backgroundEnabled", "backgroundColor", "backgroundOpacity", "backgroundRadius", "backgroundImage", "backgroundX", "backgroundY", "backgroundWidth", "backgroundHeight", "backgroundScale", "backgroundRotation", "backgroundFit", ...Object.keys(outlineDefaults)]
    function snapshot() { const result = {}; for (const key of editableKeys) result[key] = root[key]; result.backgroundImage = backgroundImageUrl; return result }
    function apply(value) { for (const key of editableKeys) root[key] = value[key] }

    property alias timeSize: saved.timeSize
    property alias accent: saved.accent
    property alias textColor: saved.textColor
    property alias title: saved.title
    property alias signature: saved.signature
    property alias widgetOpacity: saved.opacity
    property alias leftPercent: saved.leftPercent
    property alias topPercent: saved.topPercent
    property alias use24Hour: saved.use24Hour

    // Qt Settings queues writes for missing keys during load. Keep added
    // keys separate so initialization cannot snapshot the older properties.
    Settings {
        id: outline
        location: root.storagePath
        category: "RoryClock"
        property bool outlineEnabled: true
        property string outlineColor: ""
        property real outlineOpacity: 1
        property real outlineWidth: 1
    }
    Settings {
        id: saved
        location: root.storagePath
        category: "RoryClock"
        property int customWidth: 0
        property int customHeight: 0
        property string fontFamily: "Noto Sans"
        property int fontWeight: 300
        property real clockRotation: 0
        property bool showSeconds: false
        property bool showDate: true
        property real elementSpacing: 9
        property int horizontalAlignment: 1
        property int verticalAlignment: 0
        property bool backgroundEnabled: false
        property string backgroundColor: "#10090f"
        property real backgroundOpacity: 0.7
        property real backgroundRadius: 10
        property string backgroundImage: ""
        property real backgroundX: 0
        property real backgroundY: 0
        property real backgroundWidth: 0
        property real backgroundHeight: 0
        property real backgroundScale: 1
        property real backgroundRotation: 0
        property string backgroundFit: "cover"
        property string profilesData: ""
        property int timeSize: 76
        property string accent: "#ff174d"
        property string textColor: "#f3eef0"
        property string title: "ロウリィ・マーキュリー"
        property string signature: "RORY MERCURY"
        property real opacity: 0.98
        property real leftPercent: 0.075
        property real topPercent: 0.24
        property bool use24Hour: false
    }
}
