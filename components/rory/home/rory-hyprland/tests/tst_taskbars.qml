pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "TaskbarModel.js" as Model

ShellRoot {
    id: tests
    readonly property string first: "file:///tmp/rory-taskbar-first.png"
    readonly property string second: "file:///tmp/rory-taskbar-second.png"
    property bool resumed: Quickshell.env("RORY_TASKBAR_PHASE")==="restart"
    function find(item,name) {
        if(item.objectName===name)return item
        for(const child of item.children ?? []) {
            const match=find(child,name)
            if(match)return match
        }
        return null
    }
    function check(value,message) { if(!value) throw new Error(message) }
    ClockSettings {id:clock;storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")}
    ClockProfileManager {id:clocks;settings:clock}
    WallpaperSettings {id:wallpaper;externalWallpaper:true;observedWallpaper:tests.first}
    VisualizerHistory {id:history;settings:wallpaper}
    StudioProfileManager {id:audio;settings:wallpaper;controller:history;associationManager:links}
    StudioAssociations {
        id:links
        storagePath:"file://"+Quickshell.shellPath(".studio-associations.ini")
        clockManager:clocks;audioManager:audio;wallpaperSettings:wallpaper
    }
    TaskbarStore {
        id:bars
        storagePath:"file://"+Quickshell.shellPath(".taskbars.ini")
        associations:links;wallpaperSettings:wallpaper
    }
    StudioController {
        id:studio
        storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini")
        clockSettings:clock;wallpaperSettings:wallpaper;clockManager:clocks;audioManager:audio
    }
    QtObject {id:sink;property real volume:.5;property bool muted:false}
    QtObject {
        id: services
        property date now:new Date()
        property var audio:sink
        property bool batteryReady:false
        property int charge:-1
        property string batteryState:"Sin batería"
        property string networkLabel:"Sin conexión"
        property var interfaces:[]
    }
    TaskbarHost {store:bars;studio:studio;services:services;coverage:coverage}
    Window {
        visible:true;width:800;height:800
        TaskbarEditor {store:bars;studio:studio;width:500}
        Loader {
            id:panelLoader
            active:!!bars.bar
            sourceComponent:TaskbarPanel {
                barId:bars.bar.id;store:bars;studio:studio
                output:Quickshell.screens[0];services:services;coverage:coverage
            }
        }
    }
    WindowCoverage {id:coverage}
    Timer {
        interval:100;running:true;repeat:true
        property int step:0
        onTriggered: {
            if (!links.ready || !bars.ready) return
            try {
                if(tests.resumed) {
                    tests.check(bars.profileId!=="global" && bars.bars.length===1,"linked profile survived restart")
                    tests.check(bars.bar.width===537,"bar dimensions persisted")
                    tests.check(bars.bar.modules[0].id==="media","module order survived restart")
                    tests.check(bars.bar.theme==="sakura" && bars.bar.center.theme==="crimson","independent modular themes survived restart")
                    tests.check(links.appearanceFor(tests.first).bar==="sakura"
                        && links.appearanceFor(tests.first).center==="crimson","per-wallpaper Rory themes survived restart")
                    wallpaper.observedWallpaper=tests.second
                    tests.check(bars.profileId==="global" && bars.bars.length===1,"global fallback survived restart")
                    tests.check(bars.bar.theme==="crimson" && !links.appearanceFor(tests.second).bar,"unlinked wallpaper uses global")
                } else if(step++===0) {
                    tests.check(bars.bars.length===0,"initial launch adds no panels")
                    bars.create(false)
                    const original=bars.bar.id
                    bars.create(true)
                    tests.check(bars.bars.length===2 && bars.bar.id!==original,"duplicate gets a new id")
                    bars.remove("global",bars.bar.id)
                    tests.check(bars.bars[0].id===original && bars.bars.length===1,"remove leaves the original")
                    tests.check(!bars.edit("global",original,{width:0}),"invalid width rejected")
                    tests.check(bars.bar.width===720,"invalid settings were not saved")
                    tests.check(bars.saveProfile("Primer fondo",true),links.error)
                    tests.check(bars.profileId!=="global","current wallpaper selected linked profile")
                    const profile=bars.profileId
                    tests.check(bars.edit(profile,original,{width:537,autohide:true,theme:"sakura"}),bars.error)
                    tests.check(links.setAppearance(tests.first,"bar","sakura"),links.error)
                    tests.check(links.setAppearance(tests.first,"center","crimson"),links.error)
                    tests.check(links.taskbarProfile(tests.first)===profile,"setting themes preserves the taskbar link")
                    tests.check(links.setAppearance(tests.second,"center","sakura"),links.error)
                    wallpaper.observedWallpaper=tests.second
                    tests.check(bars.profileId==="global" && bars.bar.width===720,"second background uses global")
                    tests.check(bars.saveProfile("Segundo fondo",true),links.error)
                    tests.check(bars.useGlobal() && bars.profileId==="global","unlink falls back to global")
                    tests.check(links.appearanceFor(tests.second).center==="sakura","unlinking modular profile leaves appearance")
                    tests.check(links.setAppearance(tests.second,"center",""),links.error)
                    wallpaper.observedWallpaper=tests.first
                    tests.check(bars.profileId===profile && bars.bar.width===537,"first background restores its own layout")
                    tests.check(links.associationRule(tests.first).clockProfile==="" && links.associationRule(tests.first).audioProfile==="","taskbar link preserves clock/audio")
                    for (const edge of ["top","bottom","left","right","free"]) {
                        const r=Model.rect(Object.assign({},bars.bar,{edge:edge,width:4096,height:4096}),320,240)
                        tests.check(r.x>=0 && r.y>=0 && r.x+r.width<=320 && r.y+r.height<=240,"bounds on "+edge)
                    }
                    for(let cycle=0;cycle<15;cycle++) {
                        wallpaper.observedWallpaper=tests.second
                        bars.create(false)
                        bars.remove("global",bars.bar.id)
                        wallpaper.observedWallpaper=tests.first
                        tests.check(bars.profileId===profile && bars.bar.width===537,"profile survived rapid switches")
                    }
                    const config=Model.copy(bars.bar.modules)
                    config.reverse()
                    config.find(m=>m.id==="launcher").enabled=false
                    tests.check(bars.edit(profile,original,{modules:config}),bars.error)
                    tests.check(bars.bar.modules[0].id==="media" && !bars.bar.modules.find(m=>m.id==="launcher").enabled,"module order and toggles persist")
                    const groups=Model.groups([{app:"a"},{app:"b"},{app:"a"}],true)
                    tests.check(groups.length===2 && groups[0].windows.length===2,"window groups retain all windows")
                    return
                } else {
                    const panel=panelLoader.item
                    tests.check(!!panel && !panel.reveal,"autohide begins hidden")
                    panel.enter()
                    tests.check(panel.reveal,"reveal state responds to trigger")
                    const volume=tests.find(panel.contentItem,"taskbarVolume")
                    tests.check(!!volume && volume.text==="50%","module renders shared sink state")
                    volume.clicked()
                    tests.check(sink.muted,"module sends mute to shared sink")
                    sink.volume=.24
                    tests.check(volume.text==="24%","module observes volume changes")
                    panel.calendarOpen=true
                }
                console.log("TASKBAR_TEST_PASS")
                Qt.quit()
            } catch(e) {
                console.error("TASKBAR_TEST_FAIL: "+e.message)
                Qt.quit()
            }
        }
    }
}
