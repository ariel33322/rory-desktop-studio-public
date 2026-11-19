pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: wallpaper
    required property ShellScreen modelData
    required property WallpaperSettings settings
    required property WindowCoverage windowCoverage
    screen: modelData
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: settings.externalWallpaper ? "transparent" : "#10090d"
    WlrLayershell.namespace: "rory-wallpaper"
    WlrLayershell.layer: settings.externalWallpaper ? WlrLayer.Bottom : WlrLayer.Background
    mask: Region { width: 0; height: 0 }

    Image {
        anchors.fill: parent
        source: wallpaper.settings.externalWallpaper ? "" : wallpaper.settings.imageUrl
        fillMode: wallpaper.settings.fitMode === "fit" ? Image.PreserveAspectFit
            : wallpaper.settings.fitMode === "center" ? Image.Pad : Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        asynchronous: true
        cache: false
        smooth: true
    }
    Rectangle { anchors.fill: parent; visible: !wallpaper.settings.externalWallpaper; color: "black"; opacity: wallpaper.settings.dim }
    RoryAudioVisualizer {
        settings: wallpaper.settings
        windowCoverage: wallpaper.windowCoverage
        monitorName: wallpaper.hyprMonitor?.name ?? ""
    }
}
