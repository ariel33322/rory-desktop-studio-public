pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: waveEffect
    required property var settings
    required property real centerX
    required property real centerY
    required property real circleRadiusX
    required property real circleRadiusY
    required property real imageScale
    anchors.fill: parent
    property real phase: 0

    Canvas {
        id: wave
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0) return

            const scale = waveEffect.imageScale
            const cx = waveEffect.centerX
            const cy = waveEffect.centerY
            const baseRadiusX = 260 * scale
            const baseRadiusY = 244 * scale
            const gain = Math.max(0.35, Math.min(2.0, waveEffect.settings.visualizerSensitivity / 100))
            const amplitude = 22 * scale * waveEffect.settings.visualizerIntensity / 100
            const levels = waveEffect.settings.spectrum
            const testMode = waveEffect.settings.visualizerTestMode
            if (!levels.length && !testMode) return
            const count = testMode ? 240 : levels.length * 3

            ctx.save()
            ctx.beginPath()
            for (let i = 0; i <= count; i++) {
                const angle = Math.PI * 2 * i / count - Math.PI / 2
                let sample = 0
                if (testMode) {
                    sample = 0.5 + 0.5 * Math.sin(angle * 2 + waveEffect.phase)
                } else {
                    const position = ((i % count) / count) * levels.length
                    const lo = Math.floor(position) % levels.length
                    const hi = (lo + 1) % levels.length
                    const fraction = position - Math.floor(position)
                    sample = (levels[lo] * (1 - fraction) + levels[hi] * fraction) / 1000
                }
                const flow = (Math.sin(angle * 3 + waveEffect.phase) * 2.1
                    + Math.sin(angle * 5 - waveEffect.phase * 0.63) * 1.15) * scale
                const offset = testMode
                    ? 258 * scale - baseRadiusX + 13.5 * scale * Math.sin(angle * 2 + waveEffect.phase)
                        + 3.5 * scale * Math.sin(angle * 5 - waveEffect.phase * 0.63) + flow
                    : (Math.max(0, Math.min(1, sample * gain)) - 0.36) * amplitude + flow
                const x = cx + Math.cos(angle) * (baseRadiusX + offset)
                const y = cy + Math.sin(angle) * (baseRadiusY + offset * baseRadiusY / baseRadiusX)
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.closePath()
            ctx.globalAlpha = testMode ? 0.94 : Math.max(0.7, waveEffect.settings.visualizerIntensity / 100)
            ctx.strokeStyle = waveEffect.settings.visualizerColor
            ctx.lineWidth = (testMode ? 3.6 : 3.0) * scale
            ctx.shadowColor = waveEffect.settings.visualizerColor
            ctx.shadowBlur = (testMode ? 5.5 : 4.5) * scale
            ctx.stroke()
            ctx.restore()
        }
        Connections {
            target: waveEffect.settings
            function onSpectrumChanged() { wave.requestPaint() }
            function onVisualizerIntensityChanged() { wave.requestPaint() }
            function onVisualizerSensitivityChanged() { wave.requestPaint() }
            function onVisualizerColorChanged() { wave.requestPaint() }
            function onVisualizerTestModeChanged() { wave.requestPaint() }
        }
        Connections {
            target: waveEffect
            function onPhaseChanged() { wave.requestPaint() }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: true
        onTriggered: {
            waveEffect.phase += 0.055
            if (waveEffect.phase > Math.PI * 2) waveEffect.phase -= Math.PI * 2
        }
    }
}
