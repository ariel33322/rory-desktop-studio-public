import QtQuick
import QtTest

TestCase {
    name: "BarSilence"
    when: windowShown
    BarSilence {
        id: gate
        monitoring: false
        samples: [40, 0, 3]
        threshold: 0.5
        holdTime: 180
        fadeTime: 160
    }

    function test_audioAndSilence() {
        compare(gate.barOpacity, 1)
        gate.monitoring = true
        wait(gate.holdTime + gate.fadeTime)
        compare(gate.barOpacity, 1)

        gate.samples = [2, 0, 4]
        wait(55)
        compare(gate.barOpacity, 1)
        gate.samples = [20, 2, 1]
        wait(gate.holdTime)
        compare(gate.barOpacity, 1)

        gate.samples = [0, 3, 4]
        tryVerify(() => gate.barOpacity > 0 && gate.barOpacity < 1)
        tryCompare(gate, "barOpacity", 0)
        gate.samples = [6, 1, 0]
        wait(gate.holdTime)
        compare(gate.barOpacity, 0, "signal near the threshold stays hidden")
        gate.samples = [16, 1, 0]
        tryVerify(() => gate.barOpacity > 0 && gate.barOpacity < 1)
        tryCompare(gate, "barOpacity", 1)

        gate.samples = []
        tryCompare(gate, "barOpacity", 0)
        gate.reset()
        compare(gate.barOpacity, 1, "a fresh composition starts a fresh hold time")
        wait(45)
        compare(gate.barOpacity, 1)
        tryCompare(gate, "barOpacity", 0)
        gate.monitoring = false
        compare(gate.barOpacity, 1)
    }
}
