pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "TaskbarModel.js" as Model

GridLayout {
    id: module
    required property string kind
    required property var config
    required property var services
    required property var monitor
    required property var panel
    readonly property bool vertical: config.orientation==="vertical"
    readonly property var workspaces: kind==="workspaces" ? Hyprland.workspaces.values
        .filter(w=>w.id>0 && (!monitor || w.monitor===monitor)).sort((a,b)=>a.id-b.id) : []
    readonly property var windows: kind==="windows" ? Hyprland.toplevels.values.map(w=>({
        app:w.wayland?.appId || w.lastIpcObject.class || "?", window:w
    })) : []
    readonly property var player: kind==="media" ? Mpris.players.values.find(p=>p.isPlaying)
        ?? Mpris.players.values[0] ?? null : null
    readonly property bool available: kind==="battery" ? !config.hideBattery || services.batteryReady
        : kind==="media" ? !config.hideMedia || !!player?.isPlaying : true
    columns: vertical ? 1 : 999
    rowSpacing: kind==="workspaces" ? config.workspaceGap : 2
    columnSpacing: rowSpacing
    function command(value) {
        if (value.trim()) Quickshell.execDetached(["sh","-c",value])
    }
    function desktop(app) {
        const id=app.replace(/\.desktop$/i,"")
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
    }
    function icon(app) {
        const name=desktop(app)?.icon
        return name ? Quickshell.iconPath(name,true) : ""
    }
    function focusWindow(window) {
        if (window?.wayland) window.wayland.activate()
        else if (window && /^(?:0x)?[0-9a-f]+$/i.test(window.address))
            Hyprland.dispatch("focuswindow address:"+ (window.address.startsWith("0x") ? window.address : "0x"+window.address))
    }
    Loader {
        active: module.available
        sourceComponent: ({
            workspaces: workspaceModule, windows: windowModule, launcher: launcherModule,
            clock: clockModule, audio: audioModule, battery: batteryModule, network: networkModule,
            tray: trayModule, media: mediaModule
        })[module.kind]
    }
    component Grid: GridLayout {
        columns: module.vertical ? 1 : 999
        rowSpacing: module.rowSpacing
        columnSpacing: module.columnSpacing
    }
    Component {
        id: workspaceModule
        Grid {
            Repeater {
                model: module.workspaces
                TaskbarButton {
                    required property var modelData
                    config: module.config
                    text: modelData.name
                    glyph: modelData.toplevels.values.length ? "•" : ""
                    selected: modelData.active
                    description: "Espacio "+text
                    onClicked: modelData.activate()
                }
            }
        }
    }
    Component {
        id: windowModule
        Grid {
            Repeater {
                model: module.config.favorites.split(/[\n,]+/).map(id=>id.trim()).filter((id,i,list)=>id && list.indexOf(id)===i)
                TaskbarButton {
                    required property string modelData
                    config: module.config
                    iconSource: module.icon(modelData)
                    glyph: "★"
                    description: module.desktop(modelData)?.name ?? modelData
                    enabled: !!module.desktop(modelData)
                    onClicked: module.desktop(modelData)?.execute()
                }
            }
            Repeater {
                model: Model.groups(module.windows,module.config.groupWindows)
                TaskbarButton {
                    id: task
                    required property var modelData
                    config: module.config
                    iconSource: module.icon(modelData.app)
                    glyph: modelData.app.slice(0,2).toUpperCase()
                    text: modelData.windows.length>1 ? String(modelData.windows.length) : ""
                    description: modelData.windows.map(w=>w.window.title).join("\n")
                    selected: modelData.windows.some(w=>w.window.activated)
                    onClicked: {
                        const windows=modelData.windows
                        const index=windows.findIndex(w=>w.window.activated)
                        module.focusWindow(windows[(index+1)%windows.length].window)
                    }
                    Component.onCompleted: if (module.config.duration>0) appear.start()
                    SequentialAnimation {
                        id: appear
                        NumberAnimation { target: task; property:"scale"; to:0.95; duration:module.config.duration/3 }
                        NumberAnimation { target: task; property:"scale"; to:1; duration:module.config.duration/3 }
                    }
                }
            }
        }
    }
    Component {
        id: launcherModule
        TaskbarButton {
            config: module.config
            glyph:"▦"
            description:"Lanzador de aplicaciones"
            enabled: module.config.launcher.trim()!==""
            onClicked: module.command(module.config.launcher)
        }
    }
    Component {
        id: clockModule
        TaskbarButton {
            id: time
            config: module.config
            text: Qt.formatTime(module.services.now,module.config.hour24 ? "HH:mm" : "hh:mm AP")
                +(module.config.date ? " · "+Qt.formatDate(module.services.now,module.config.dateFormat) : "")
            onClicked: module.panel.calendarOpen=!module.panel.calendarOpen
        }
    }
    Component {
        id: audioModule
        TaskbarButton {
            objectName:"taskbarVolume"
            config: module.config
            text: module.services.audio ? Math.round(module.services.audio.volume*100)+"%" : "—"
            glyph: module.services.audio?.muted ? "×" : "♪"
            description:"Volumen · clic para silenciar, rueda para ajustar"
            enabled: !!module.services.audio
            onClicked: module.services.audio.muted=!module.services.audio.muted
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event=>{
                    const audio=module.services.audio
                    if (audio) audio.volume=Math.max(0,Math.min(1,audio.volume+Math.sign(event.angleDelta.y)*module.config.volumeStep/100))
                }
            }
        }
    }
    Component {
        id: batteryModule
        TaskbarButton {
            config: module.config
            text: module.services.batteryReady ? module.services.charge+"%" : "—"
            glyph: UPower.onBattery ? "◩" : "ϟ"
            description: module.services.batteryState
            enabled: false
        }
    }
    Component {
        id: networkModule
        TaskbarButton {
            config: module.config
            text: module.services.networkLabel
            glyph: module.services.interfaces.some(device=>device.connected) ? "●" : "○"
            onClicked: module.command(module.config.network)
        }
    }
    Component {
        id: trayModule
        Grid {
            Repeater {
                model: SystemTray.items
                TaskbarButton {
                    id: tray
                    required property var modelData
                    config: module.config
                    iconSource: modelData.icon
                    glyph:"◈"
                    description:modelData.tooltipTitle || modelData.title
                    onClicked: modelData.onlyMenu ? openMenu() : modelData.activate()
                    function openMenu() {
                        if (modelData.hasMenu) {
                            const at=mapToItem(null,0,height)
                            modelData.display(module.panel,Math.round(at.x),Math.round(at.y))
                        }
                    }
                    TapHandler { acceptedButtons:Qt.RightButton; onTapped:tray.openMenu() }
                    TapHandler { acceptedButtons:Qt.MiddleButton; onTapped:tray.modelData.secondaryActivate() }
                    WheelHandler {onWheel:event=>tray.modelData.scroll(event.angleDelta.y || event.angleDelta.x,!event.angleDelta.y)}
                }
            }
        }
    }
    Component {
        id: mediaModule
        Grid {
            Image {
                visible: status===Image.Ready
                source: module.player?.trackArtUrl ?? ""
                Layout.preferredWidth: module.config.iconSize
                Layout.preferredHeight: width
                fillMode:Image.PreserveAspectFit
                asynchronous:true
            }
            TaskbarButton {config:module.config;glyph:"‹";description:"Pista anterior";enabled:module.player?.canGoPrevious ?? false;onClicked:module.player.previous()}
            TaskbarButton {
                config:module.config
                glyph:module.player?.isPlaying ? "Ⅱ" : "▶"
                text: module.player ? [module.player.trackTitle,module.player.trackArtist].filter(Boolean).join(" · ") || module.player.identity
                    : "Sin reproducción"
                description:[module.player?.trackTitle,module.player?.trackArtist].filter(Boolean).join(" · ")
                enabled:module.player?.canTogglePlaying ?? false
                onClicked:module.player.togglePlaying()
            }
            TaskbarButton {config:module.config;glyph:"›";description:"Pista siguiente";enabled:module.player?.canGoNext ?? false;onClicked:module.player.next()}
        }
    }
}
