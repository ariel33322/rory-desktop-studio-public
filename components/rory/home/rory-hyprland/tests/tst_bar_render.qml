import QtQuick
import QtTest
import "AudioLayers.js" as Layers
import "visualizer-layers" as V2

Rectangle {
    id: stage
    width: 360
    height: 300
    color: "#202020"

    QtObject {
        id: input
        readonly property var loud: Array(24).fill(1000)
        readonly property var quiet: Array(24).fill(0)
        property var spectrum: loud
        property bool hideSilentBars: false
        readonly property real barSilenceOpacity: gate.barOpacity
        readonly property bool effectiveVisualizerEnabled: true
        readonly property bool visualizerTestMode: false
        readonly property int visualizerBarCount: 24
        readonly property string visualizerGeometry: "circle"
        readonly property string visualizerShapeMode: "linked"
        readonly property string visualizerShapeData: "{}"
        readonly property string visualizerIndependentVertices: "[]"
        readonly property real visualizerOffset: 0
        readonly property real visualizerOrientation: 0
        readonly property real visualizerSensitivity: 100
        readonly property real visualizerBass: 0
        readonly property real visualizerAttack: 95
        readonly property real visualizerSmoothing: 2
        readonly property real visualizerIntensity: 100
        readonly property string visualizerColor: "#ff0000"
    }

    BarSilence {
        id: gate
        monitoring: input.hideSilentBars
        samples: input.spectrum
        threshold: 0.5
        holdTime: 160
        fadeTime: 100
    }

    RadialSpectrum {
        settings: input
        centerX: 90
        centerY: 90
        circleRadiusX: 40
        circleRadiusY: 40
        imageScale: 1
    }

    TestCase {
        name: "BarRender"
        when: windowShown

        function scene(cuts) {
            const red = Layers.layerV2("main")
            red.common.color = "#ff0000"
            red.common.opacity = 100
            red.styles.bars = "classic"
            Object.assign(red.params.bars, {length:30, thickness:4, intensity:100})
            if (cuts) red.cuts.intervals = cuts
            const blue = Layers.copy(red)
            blue.id = "layer-1"
            blue.common.color = "#0000ff"
            blue.common.x = 180
            blue.cuts.intervals = []
            const wave = Layers.layerV2("layer-2")
            wave.type = "waves"
            wave.common.color = "#00ff00"
            wave.common.opacity = 100
            wave.common.y = 135
            // With zero displacement these wave pixels must be identical in
            // the active, silent and clipped images.
            wave.params.waves.amplitude = 0
            wave.params.waves.thickness = 3
            V2.VisualizerLayersStore.document = JSON.stringify({
                version:2, order:[red.id,blue.id,wave.id], layers:[red,blue,wave]
            })
        }

        function init() {
            input.hideSilentBars = false
            input.spectrum = input.loud
            scene()
        }

        function frame() {
            const image = grabImage(stage)
            const result = {red:0, redNear:0, redFar:0, redRight:0, redLeft:[],
                            redUpperRight:0, redLowerRight:0, redTint:0, blueTint:0, blue:[], green:[]}
            for (let y=0; y<image.height; ++y) {
                for (let x=0; x<image.width; ++x) {
                    const r = image.red(x,y), g = image.green(x,y), b = image.blue(x,y)
                    const index = y * image.width + x
                    if (r>g+2 && r>b+2) ++result.redTint
                    if (b>r+2 && b>g+2) ++result.blueTint
                    if (r>85 && r>g+40 && r>b+40) {
                        ++result.red
                        const radius = Math.hypot(x-90,y-90)
                        if (radius<49) ++result.redNear
                        if (radius>53) ++result.redFar
                        // Stay away from the antialiased edge of the half cut.
                        if (x<84) result.redLeft.push(index * 256 + r)
                        if (x>96) {
                            ++result.redRight
                            if (y<84) ++result.redUpperRight
                            if (y>96) ++result.redLowerRight
                        }
                    } else if (g>85 && g>r+40 && g>b+40) {
                        result.green.push(index * 256 + g)
                    } else if (b>85 && b>r+40 && b>g+40) {
                        result.blue.push(index * 256 + b)
                    }
                }
            }
            result.background = image.pixel(0,0)
            return result
        }

        function activeFrame() {
            let pixels
            tryVerify(() => {
                pixels = frame()
                return pixels.redFar>100 && pixels.blue.length>100 && pixels.green.length>100
            }, 2500, "Active signal must paint visible bars beyond their minimum radius, plus the independent wave")
            return pixels
        }

        function test_audioSilenceAndMinimumHeight() {
            const active = activeFrame()
            input.spectrum = input.quiet
            let minimum
            tryVerify(() => {
                minimum = frame()
                return minimum.redFar===0 && minimum.redNear>0 && minimum.blue.length>0
            }, 2500, "With silence hiding disabled, zero signal still paints minimum-height bars")
            verify(minimum.red < active.red)
            compare(minimum.green,active.green)
            compare(minimum.background,active.background)

            input.hideSilentBars = true
            let hidden
            tryVerify(() => {
                hidden = frame()
                return input.barSilenceOpacity===0 && hidden.redTint===0 && hidden.blueTint===0
            }, 2500, "Sustained silence must remove every painted bar, including the minimum height")
            compare(hidden.green,active.green)
            compare(hidden.background,active.background)

            input.spectrum = input.loud
            const resumed = activeFrame()
            compare(resumed.green,active.green)
            compare(resumed.background,active.background)
        }

        function test_cutOnlyChangesSelectedBars() {
            const active = activeFrame()
            verify(active.redRight>100 && active.redLeft.length>100)
            const cut = {start:0,length:.5,visible:false}
            scene([cut])
            let clipped
            tryVerify(() => {
                clipped = frame()
                return clipped.redRight===0 && clipped.redLeft.length>100
            }, 2500, "The hidden half must remove its bars while leaving the opposite half visible")
            compare(clipped.redLeft,active.redLeft)
            compare(clipped.blue,active.blue)
            compare(clipped.green,active.green)
            compare(clipped.background,active.background)

            scene([cut,{start:0,length:.25,visible:true}])
            let restored
            tryVerify(() => {
                restored = frame()
                return restored.redUpperRight>100 && restored.redLowerRight===0
            }, 2500, "Restoring a quarter must leave the other hidden quarter empty")
            compare(restored.redUpperRight,active.redUpperRight)
            compare(restored.redLeft,active.redLeft)
            compare(restored.blue,active.blue)
            compare(restored.green,active.green)
        }
    }
}
