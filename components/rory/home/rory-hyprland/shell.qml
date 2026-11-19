pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    readonly property string deckSocket: Quickshell.env("XDG_RUNTIME_DIR") + "/skwd-wall-v2/wall.sock"
    property string referenceOutput: Quickshell.env("RORY_REFERENCE_OUTPUT")

    Connections { target: Quickshell; function onScreensChanged() { root.chooseReferenceOutput() } }
    function chooseReferenceOutput() {
        if (!referenceOutput)
            referenceOutput = Quickshell.screens.map(screen => screen.name).sort()[0] ?? ""
    }
    Component.onCompleted: chooseReferenceOutput()

    DeckWallpaperObserver {
        id: deckObserver
        endpoint: root.deckSocket
        referenceOutput: root.referenceOutput
        onPathChanged: if (path) console.info("RORY_DECK_WALLPAPER", path)
    }
    SystemState { id: systemState }
    ClockSettings { id: clockSettings
        storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")
        onEditorOpenChanged: studio.externalClockOpened()
    }
    ClockProfileManager { id: clockProfiles; settings: clockSettings }
    StudioController {
        id:studio
        storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini")
        clockSettings:clockSettings;wallpaperSettings:wallpaperSettings
        clockManager:clockProfiles;audioManager:studioProfiles
        screens:Quickshell.screens
    }
    StudioAssociations {
        id:associations
        storagePath:"file://"+Quickshell.shellPath(".studio-associations.ini")
        clockManager:clockProfiles;audioManager:studioProfiles;wallpaperSettings:wallpaperSettings
    }
    Connections {
        target:wallpaperSettings
        function onVisualizerEditorOpenChanged(){studio.externalAudioOpened()}
    }
    WallpaperSettings { id: wallpaperSettings;profileManager:studioProfiles;studioController:studio;studioVisibility:associations.audioVisible;externalWallpaper:!!root.deckSocket;observedWallpaper:deckObserver.path }
    VisualizerHistory {id:visualizerHistory;settings:wallpaperSettings}
    StudioProfileManager {id:studioProfiles;controller:visualizerHistory;settings:wallpaperSettings;associationManager:associations}
    Variants {
        id: studioLaunchers
        reloadableId: "studioLaunchers"
        model:Quickshell.screens
        StudioLauncher {studio:studio;associations:associations}
    }
    Variants {
        id: wallpaperPrompts
        reloadableId: "wallpaperPrompts"
        model:Quickshell.screens
        StudioWallpaperPrompt {associations:associations;studio:studio}
    }
    // The clock is always part of the desktop, so keep one shared coverage
    // detector alive whether or not the audio visualizer is enabled.
    WindowCoverage { id: windowCoverage; monitoring: true }

    Variants {
        id: bars
        reloadableId: "bars"
        model: Quickshell.screens
        RoryBar { services: systemState; wallpaperSettings: wallpaperSettings }
    }

    Variants {
        id: wallpapers
        reloadableId: "wallpapers"
        model: Quickshell.screens
        WallpaperDisplay {
            settings: wallpaperSettings
            windowCoverage: windowCoverage
        }
    }

    Variants {
        id: audioEditors
        reloadableId: "audioEditors"
        model: Quickshell.screens
        VisualizerEditor { settings: wallpaperSettings;profileManager:studioProfiles;studio:studio }
    }

    Variants {
        id: desktopClocks
        reloadableId: "desktopClocks"
        model: Quickshell.screens
        ClockWidget {
            settings: clockSettings
            displayEnabled:associations.clockVisible
            externalWallpaper:wallpaperSettings.externalWallpaper
            windowCoverage: windowCoverage
        }
    }

    Variants {
        id: clockEditors
        reloadableId: "clockEditors"
        model: Quickshell.screens
        ClockEditor { settings: clockSettings;profileManager:clockProfiles;studio:studio;associations:associations }
    }

    IpcHandler {
        target: "rory"
        function clockCount(): int { return desktopClocks.instances.length }
        function stop(): void { Qt.quit() }
        function toggleAudioEditor(): void {
            if(studio.centralShortcut)studio.toggle()
            else if (wallpaperSettings.visualizerEditorOpen) closeAudioEditor()
            else openAudioEditor()
        }
        function openStudio(): void { studio.home(null) }
        function toggleStudio(): void { studio.toggle() }
        function closeStudio(): void { studio.close() }
        function openStudioWallpapers(): void { studio.open("wallpapers",null) }
        function openAudioEditor(): void { studio.open("audio",null) }
        function closeAudioEditor(): void {
            studio.finishInputs()
            wallpaperSettings.visualizerPointerEditMode = false
            wallpaperSettings.visualizerEditorOpen = false
        }
        function openClockEditor(): void { studio.open("clock",null) }
        function closeClockEditor(): void { clockSettings.editorOpen = false; clockSettings.pointerEditMode = false }
    }
}
