pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: preview
    property string testWallpaper:""
    DeckWallpaperObserver {
        id: deck
        endpoint:Quickshell.env("XDG_RUNTIME_DIR")+"/skwd-wall-v2/wall.sock"
        referenceOutput:Quickshell.screens.map(s=>s.name).sort()[0] ?? ""
    }
    SystemState {id:services}
    WindowCoverage {id:coverage;monitoring:true}
    WallpaperSettings {
        id:wallpaper
        externalWallpaper:true
        observedWallpaper:preview.testWallpaper || deck.path
        studioVisibility:false
    }
    ClockSettings {id:clock;storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")}
    ClockProfileManager {id:clocks;settings:clock}
    VisualizerHistory {id:history;settings:wallpaper}
    StudioProfileManager {id:audio;controller:history;settings:wallpaper;associationManager:links}
    StudioAssociations {
        id:links
        storagePath:"file://"+Quickshell.shellPath(".studio-associations.ini")
        clockManager:clocks;audioManager:audio;wallpaperSettings:wallpaper
    }
    StudioController {
        id:studio
        storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini")
        clockSettings:clock;wallpaperSettings:wallpaper;clockManager:clocks;audioManager:audio
        screens:Quickshell.screens
    }
    CrimsonCoordinator {id:crimson;services:services}
    TaskbarStore {
        id:bars
        crimson:crimson
        storagePath:"file://"+Quickshell.shellPath(".taskbars.ini")
        associations:links;wallpaperSettings:wallpaper
    }
    TaskbarHost {store:bars;studio:studio;services:services;coverage:coverage}
    Variants {
        model:Quickshell.screens
        StudioLauncher {studio:studio;associations:links;taskbars:bars}
    }
    IpcHandler {
        target:"taskbarPreview"
        function open():void {studio.open("taskbars",null)}
        function close():void {studio.close()}
        function wallpaperOverride(url:string):void {preview.testWallpaper=url}
        function stop():void {Qt.quit()}
    }
    Component.onCompleted:studio.open("taskbars",null)
}
