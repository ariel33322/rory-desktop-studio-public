import QtQuick

Canvas {
    id: glyph
    required property string kind
    property color ink: "#e290a4"
    property real level: 1
    property bool off: false
    property bool charging: false
    implicitWidth: 16
    implicitHeight: 16
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onLevelChanged: requestPaint()
    onOffChanged: requestPaint()
    onChargingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.scale(width / 16, height / 16)
        ctx.strokeStyle = ink
        ctx.fillStyle = ink
        ctx.lineWidth = 1.3
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()

        switch (kind) {
        case "wallpaper":
            ctx.moveTo(2, 3)
            ctx.lineTo(14, 3)
            ctx.lineTo(14, 13)
            ctx.lineTo(2, 13)
            ctx.closePath()
            ctx.moveTo(3.5, 11)
            ctx.lineTo(6.6, 7.5)
            ctx.lineTo(8.4, 9.1)
            ctx.lineTo(10.4, 6.8)
            ctx.lineTo(13, 10)
            ctx.moveTo(10.5, 5.3)
            ctx.arc(10.5, 5.3, 0.7, 0, 2 * Math.PI)
            break
        case "network":
            for (const radius of [3, 6, 9]) {
                ctx.moveTo(8 - radius / Math.sqrt(2), 13 - radius / Math.sqrt(2))
                ctx.arc(8, 13, radius, 1.25 * Math.PI, 1.75 * Math.PI)
            }
            ctx.fillRect(7.4, 12.3, 1.2, 1.2)
            break
        case "ethernet":
            ctx.rect(2.5, 3, 11, 8)
            ctx.moveTo(6, 13.5)
            ctx.lineTo(10, 13.5)
            ctx.moveTo(8, 11)
            ctx.lineTo(8, 13.5)
            break
        case "bluetooth":
            ctx.moveTo(4, 4)
            ctx.lineTo(11.5, 11)
            ctx.lineTo(8, 14)
            ctx.lineTo(8, 2)
            ctx.lineTo(11.5, 5)
            ctx.lineTo(4, 12)
            break
        case "audio":
            ctx.moveTo(2, 6)
            ctx.lineTo(5, 6)
            ctx.lineTo(8, 3.5)
            ctx.lineTo(8, 12.5)
            ctx.lineTo(5, 10)
            ctx.lineTo(2, 10)
            ctx.closePath()
            if (!off && level > 0) {
                ctx.moveTo(10, 5.8)
                ctx.quadraticCurveTo(12.5, 8, 10, 10.2)
                if (level >= 0.5) {
                    ctx.moveTo(12, 4)
                    ctx.quadraticCurveTo(15.7, 8, 12, 12)
                }
            }
            break
        case "battery":
            ctx.rect(1.5, 4, 11.5, 8)
            ctx.moveTo(14.5, 6.2)
            ctx.lineTo(14.5, 9.8)
            if (!off && !charging) ctx.fillRect(3.1, 5.5, 8.4 * Math.max(0, Math.min(1, level)), 5)
            if (charging) {
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(8.9, 3)
                ctx.lineTo(5.1, 8.7)
                ctx.lineTo(7.8, 8.7)
                ctx.lineTo(6.4, 13)
                ctx.lineTo(10.8, 7.1)
                ctx.lineTo(8, 7.1)
                ctx.closePath()
                ctx.fill()
            }
            break
        case "power":
            ctx.moveTo(8, 2)
            ctx.lineTo(8, 7)
            ctx.moveTo(11.5, 4.2)
            ctx.arc(8, 8.5, 5.5, -0.28 * Math.PI, 1.28 * Math.PI)
            break
        }
        ctx.stroke()
        if (off) {
            ctx.beginPath()
            ctx.moveTo(2, 2)
            ctx.lineTo(14, 14)
            ctx.stroke()
        }
    }
}
