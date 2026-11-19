pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: gate
    required property bool monitoring
    required property var samples
    required property real threshold
    required property int holdTime
    required property int fadeTime

    // CAVA emits magnitudes from 0 to 1000. Keep quiet but nonzero frames in the test.
    readonly property real level: monitoring ? Math.max(0, ...samples) / 10 : 0
    readonly property real wakeLevel: threshold + Math.max(0.05, threshold * 0.25)
    property real barOpacity: 1
    property bool hiddenForSilence: false

    function reset() {
        quietTimer.stop()
        fade.stop()
        hiddenForSilence = false
        barOpacity = 1
        evaluate()
    }
    function fadeTo(target) {
        fade.stop()
        fade.to = target
        fade.start()
    }
    function evaluate() {
        if (!monitoring) return
        if (hiddenForSilence) {
            if (level > wakeLevel) {
                hiddenForSilence = false
                fadeTo(1)
            }
        } else if (level > threshold) {
            quietTimer.stop()
        } else if (!quietTimer.running) {
            quietTimer.start()
        }
    }
    onMonitoringChanged: reset()
    onLevelChanged: evaluate()
    onThresholdChanged: reset()
    onHoldTimeChanged: reset()
    Component.onCompleted: reset()

    readonly property Timer quietTimer: Timer {
        interval: gate.holdTime
        onTriggered: {
            gate.hiddenForSilence = true
            gate.fadeTo(0)
        }
    }
    readonly property NumberAnimation fade: NumberAnimation {
        target: gate
        property: "barOpacity"
        duration: gate.fadeTime
        easing.type: Easing.InOutQuad
    }
}
