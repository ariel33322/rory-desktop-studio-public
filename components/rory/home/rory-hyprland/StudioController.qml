pragma ComponentBehavior: Bound
import QtQuick
import QtCore

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
    property alias centralShortcut:saved.centralShortcut
    property alias shortcutLabel:saved.shortcutLabel
    readonly property var destinations: [
        {id:"home",title:"Menú principal"},
        {id:"audio",title:"Visualizador de audio"},
        {id:"clock",title:"Reloj"},
        {id:"wallpapers",title:"Fondos de pantalla"},
        {id:"associations",title:"Asociaciones de perfiles"},
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
