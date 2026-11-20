pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Text {
    id: label
    required property ClockSettings settings
    required property color fillColor
    required property color originalOutline
    property bool individual: false
    property real strokeWidth: settings.outlineWidth
    readonly property bool outlined: individual ? strokeWidth > 0 : settings.outlineEnabled && settings.outlineOpacity > 0
    readonly property bool vectorOutline: outlined && strokeWidth !== 1
    readonly property color outlineInk: {
        if (individual) return originalOutline
        const ink = settings.outlineColor === "" ? originalOutline : Qt.color(settings.outlineColor)
        return Qt.rgba(ink.r, ink.g, ink.b, ink.a * settings.outlineOpacity)
    }

    color: vectorOutline ? "transparent" : fillColor
    style: outlined && !vectorOutline ? Text.Outline : Text.Normal
    styleColor: outlineInk

    Loader {
        anchors.fill: parent
        active: label.vectorOutline
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.WindingFill
                fillColor: label.fillColor
                strokeColor: label.outlineInk
                strokeWidth: label.strokeWidth
                joinStyle: ShapePath.RoundJoin
                PathText {
                    x: label.effectiveHorizontalAlignment === Text.AlignHCenter ? (label.width - label.contentWidth) / 2
                        : label.effectiveHorizontalAlignment === Text.AlignRight ? label.width - label.contentWidth : 0
                    y: label.baselineOffset
                    text: label.text
                    font: label.font
                }
            }
        }
    }
}
