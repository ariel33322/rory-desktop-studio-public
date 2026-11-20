pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import "TaskbarModel.js" as Taskbar
import "RoryTheme.js" as Theme

Item {
    id:studio
    required property url storagePath
    visible:false;width:0;height:0
    required property var clockSettings
    required property var wallpaperSettings
    required property var clockManager
    required property var audioManager
    property var screens:[]
    property var activeScreen:null
    property string page:""
    readonly property var targetScreen: screens.includes(activeScreen) ? activeScreen : screens[0] || null
    onTargetScreenChanged: {
        if (clockSettings.editorOpen) clockSettings.editorScreen = targetScreen
        if (!targetScreen) clockSettings.pointerEditMode = false
    }
    property var associations:null
    readonly property var sakuraDecoration:sakuraSettings.config
    readonly property string sakuraDecorationError:sakuraSettings.error
    signal sakuraPreviewRequested(var output)
    function editSakuraDecoration(key,value){return sakuraSettings.edit(key,value)}
    function previewSakuraDecoration() {
        if(roryBarTheme==="sakura" && targetScreen && sakuraDecoration.enabled)
            sakuraPreviewRequested(targetScreen)
    }
    SakuraDecorationSettings {id:sakuraSettings;storagePath:studio.storagePath}
    property alias notificationOptions: notificationSettings
    Settings {
        id: notificationSettings
        location: studio.storagePath
        category: "RoryBarNotifications"
        property bool showIcon: true
        property bool receive: false
        property bool quiet: false
        property bool groupByApp: true
        property bool showMedia: true
        property bool animate: true
        property int panelWidth: 400
        property int maxHeight: 650
        property int offset: 0
        property real opacity: .96
        property int openMs: 170
        property int closeMs: 140
    }
    property alias globalBarTheme:themeSettings.bar
    property alias globalCenterTheme:themeSettings.center
    readonly property var wallpaperThemes:associations?.appearanceFor(wallpaperSettings.activeWallpaper) ?? ({})
    readonly property string roryBarTheme:wallpaperThemes.bar || (Theme.valid(globalBarTheme) ? globalBarTheme : "sakura")
    readonly property string roryCenterTheme:wallpaperThemes.center || (Theme.valid(globalCenterTheme) ? globalCenterTheme : "sakura")
    readonly property var effectiveRoryCrimson:Object.assign({},roryCrimson,{theme:roryCenterTheme})
    function setWallpaperTheme(component,theme) {
        return associations?.setAppearance(wallpaperSettings.activeWallpaper,component,theme) ?? false
    }
    Settings {
        id:themeSettings
        location:studio.storagePath
        category:"RoryTheme"
        property string bar:"sakura"
        property string center:"sakura"
    }
    readonly property var roryCrimson: {
        try {
            const config=JSON.parse(crimsonSettings.data)
            Taskbar.validateCenter(config)
            return config
        } catch (_) { return Taskbar.centerDefaults() }
    }
    property string roryCrimsonError: ""
    readonly property var roryCrimsonInputs: QtObject {
        property var pending: []
        function beginTransaction() {}
        function endTransaction() {}
        function setInputPending(item, dirty) {
            pending=pending.filter(input=>input && input!==item)
            if(dirty) pending=pending.concat([item])
        }
        function finish() {
            for(const item of pending.slice()) item?.finishForProfile()
        }
    }
    function saveRoryCrimson(config) {
        try {
            Taskbar.validateCenter(config)
            crimsonSettings.data=JSON.stringify(config)
            roryCrimsonError=""
        } catch(e) { roryCrimsonError=String(e.message || e) }
    }
    Settings {
        id:crimsonSettings
        location:studio.storagePath
        category:"RoryBarCrimson"
        property string data:""
    }
    property alias centralShortcut:saved.centralShortcut
    property alias shortcutLabel:saved.shortcutLabel
    readonly property var destinations: [
        {id:"home",title:"Menú principal"},
        {id:"audio",title:"Visualizador de audio"},
        {id:"clock",title:"Reloj"},
        {id:"wallpapers",title:"Fondos de pantalla"},
        {id:"associations",title:"Asociaciones de perfiles"},
        {id:"taskbars",title:"Barra de tareas"},
        {id:"settings",title:"Configuración de Studio"}
    ]
    Settings {
        id:saved
        location:studio.storagePath
        category:"RoryDesktopStudio"
        // Keep the old shortcut behavior until the user verifies the launcher.
        property bool centralShortcut:false
        property string shortcutLabel:"SUPER + P"
    }
    function finishInputs() {
        roryCrimsonInputs.finish()
        clockManager.controller.endTransaction()
        audioManager.controller.finishPendingInputs()
        audioManager.controller.endTransaction()
    }
    function open(destination,targetScreen) {
        finishInputs()
        wallpaperSettings.visualizerPointerEditMode=false
        page=""
        clockSettings.editorOpen=false;clockSettings.pointerEditMode=false
        wallpaperSettings.visualizerEditorOpen=false
        activeScreen=targetScreen || studio.targetScreen
        if(destination==="clock") {
            clockSettings.editorScreen=activeScreen;clockSettings.editorOpen=true
        } else if(destination==="audio")wallpaperSettings.visualizerEditorOpen=true
        else page=destination || "home"
    }
    function home(targetScreen) {open("home",targetScreen)}
    function close() {
        finishInputs()
        page=""
        clockSettings.editorOpen=false
        clockSettings.pointerEditMode=false
        wallpaperSettings.visualizerEditorOpen=false
        wallpaperSettings.visualizerPointerEditMode=false
    }
    function toggle() {
        if(page!=="" || clockSettings.editorOpen || wallpaperSettings.visualizerEditorOpen) {
            close()
        }else home(null)
    }
    function externalClockOpened() {
        if(!clockSettings.editorOpen)return
        page="";clockSettings.pointerEditMode=false
        activeScreen=clockSettings.editorScreen || targetScreen
        clockSettings.editorScreen=targetScreen
        wallpaperSettings.visualizerEditorOpen=false
        wallpaperSettings.visualizerPointerEditMode=false
    }
    function externalAudioOpened() {
        if(!wallpaperSettings.visualizerEditorOpen)return
        page="";clockSettings.editorOpen=false;clockSettings.pointerEditMode=false
    }
}
