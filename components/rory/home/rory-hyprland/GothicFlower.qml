pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: flower
    property real bloom: 0
    width: 78
    height: 78
    visible: bloom > 0
    opacity: Math.min(1, bloom * 3)

    Repeater {
        model: 6
        Image {
            required property int index
            x: 27
            y: 0
            width: 24
            height: 46
            source: "art/floral-petal.svg"
            sourceSize.width: 32
            sourceSize.height: 60
            transformOrigin: Item.Bottom
            rotation: index * 60 - 15 + (1 - flower.bloom) * 22
            transform: Scale {
                origin.x: 12
                origin.y: 42
                xScale: 0.12 + flower.bloom * 0.88
                yScale: 0.18 + flower.bloom * 0.82
            }
        }
    }

    Canvas {
        x: 26
        y: 30
        width: 26
        height: 26
        scale: 0.3 + 0.7 * flower.bloom
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#290a16"
            ctx.fillStyle = "#fe4758"
            ctx.lineWidth = 1.1
            for (let i = 0; i < 7; i++) {
                const angle = i * Math.PI * 2 / 7
                const x = 13 + Math.cos(angle) * 10
                const y = 13 + Math.sin(angle) * 10
                ctx.beginPath()
                ctx.moveTo(13, 13)
                ctx.quadraticCurveTo(13 + Math.cos(angle + 0.6) * 8,
                                     13 + Math.sin(angle + 0.6) * 8, x, y)
                ctx.stroke()
                ctx.beginPath()
                ctx.ellipse(x - 1, y - 1, 2, 2)
                ctx.fill()
            }
        }
    }
}
