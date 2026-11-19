pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: vine
    property real growth: 0
    property bool reflected: false
    width: 365
    height: 182
    visible: growth > 0
    enabled: false

    function phase(start, span) {
        return Math.max(0, Math.min(1, (growth - start) / span))
    }

    Item {
        width: 365
        height: 182
        transform: Scale {
            origin.x: 182.5
            xScale: vine.reflected ? -1 : 1
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "#b81a32"
                strokeWidth: 1.45
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: vine.phase(0, 0.70)
                startX: 0
                startY: 0
                PathCubic { control1X: 42; control1Y: -2; control2X: 60; control2Y: 48; x: 110; y: 44 }
                PathCubic { control1X: 177; control1Y: 100; control2X: 245; control2Y: -4; x: 304; y: 9 }
                PathCubic { control1X: 339; control1Y: 31; control2X: 354; control2Y: 5; x: 327; y: 5 }
            }

            ShapePath {
                strokeColor: "#a11429"
                strokeWidth: 1.35
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: vine.phase(0.08, 0.64)
                startX: 39
                startY: 13
                PathCubic { control1X: 78; control1Y: 27; control2X: 55; control2Y: 57; x: 62; y: 69 }
                PathCubic { control1X: 72; control1Y: 77; control2X: 76; control2Y: 61; x: 64; y: 61 }
            }

            ShapePath {
                strokeColor: "#b91b33"
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: vine.phase(0.19, 0.54)
                startX: 111
                startY: 44
                PathCubic { control1X: 93; control1Y: 81; control2X: 77; control2Y: 120; x: 98; y: 147 }
                PathCubic { control1X: 110; control1Y: 162; control2X: 108; control2Y: 169; x: 104; y: 179 }
            }

            ShapePath {
                strokeColor: "#8b0f24"
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: vine.phase(0.30, 0.43)
                startX: 112
                startY: 46
                PathCubic { control1X: 144; control1Y: 67; control2X: 152; control2Y: 107; x: 127; y: 121 }
                PathCubic { control1X: 115; control1Y: 123; control2X: 115; control2Y: 105; x: 127; y: 108 }
            }

            ShapePath {
                strokeColor: "#b1182d"
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: vine.phase(0.32, 0.39)
                startX: 215
                startY: 36
                PathCubic { control1X: 222; control1Y: 12; control2X: 245; control2Y: -9; x: 267; y: 1 }
                PathCubic { control1X: 288; control1Y: 7; control2X: 281; control2Y: 38; x: 277; y: 47 }
            }
        }

        Repeater {
            model: [
                { x: 28, y: 12, angle: -42, at: 0.18 },
                { x: 54, y: 39, angle: 49, at: 0.28 },
                { x: 88, y: 22, angle: -40, at: 0.30 },
                { x: 140, y: 55, angle: 68, at: 0.42 },
                { x: 186, y: 57, angle: -52, at: 0.48 },
                { x: 215, y: 27, angle: -43, at: 0.53 },
                { x: 259, y: 10, angle: 42, at: 0.60 },
                { x: 96, y: 83, angle: 39, at: 0.50 },
                { x: 81, y: 126, angle: -30, at: 0.61 },
                { x: 109, y: 157, angle: 22, at: 0.66 },
                { x: 127, y: 113, angle: 28, at: 0.64 },
                { x: 276, y: 44, angle: -15, at: 0.66 }
            ]
            Image {
                required property var modelData
                readonly property real opening: vine.phase(modelData.at, 0.13)
                x: modelData.x - width / 2
                y: modelData.y - height
                width: 15
                height: 23
                source: "assets/floral-leaf.svg"
                sourceSize.width: 22
                sourceSize.height: 34
                transformOrigin: Item.Bottom
                rotation: modelData.angle + (1 - opening) * 25
                scale: opening
                opacity: opening
                visible: opening > 0
            }
        }

        GothicFlower {
            x: 72
            y: 4
            bloom: vine.phase(0.73, 0.27)
        }
    }
}
