pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: visualizer
    required property WallpaperSettings settings
    required property WindowCoverage windowCoverage
    required property string monitorName
    anchors.fill: parent
    visible: settings.effectiveVisualizerEnabled && settings.visualizerEffect === "radial"
        && !windowCoverage.isCovered(monitorName, "visualizer")

    readonly property real imageScale: settings.fitMode === "fit"
        ? Math.min(width / 1920, height / 1080)
        : settings.fitMode === "center" ? 1
        : Math.max(width / 1920, height / 1080)
    readonly property real imageX: (width - 1920 * imageScale) / 2
    readonly property real imageY: (height - 1080 * imageScale) / 2
    readonly property real centerX: imageX + settings.visualizerCenterX * imageScale
    readonly property real centerY: imageY + settings.visualizerCenterY * imageScale
    // The reference ring is slightly vertically compressed in the source image.
    readonly property real circleRadiusX: settings.visualizerEffectiveRadiusX * imageScale * settings.visualizerScale
    readonly property real circleRadiusY: settings.visualizerEffectiveRadiusY * imageScale * settings.visualizerScale

    Loader {
        anchors.fill: parent
        z: 4
        active: visualizer.visible
        sourceComponent: radialSpectrum
    }
    Component {
        id: radialSpectrum
        RadialSpectrum {
            settings: visualizer.settings
            centerX: visualizer.centerX
            centerY: visualizer.centerY
            circleRadiusX: visualizer.circleRadiusX
            circleRadiusY: visualizer.circleRadiusY
            imageScale: visualizer.imageScale * visualizer.settings.visualizerScale
        }
    }
}
