pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "SakuraDecoration.js" as Sakura

Rectangle {
    id: scene
    width: 640
    height: 280
    color: "#25101e"

    SakuraDecorationSettings {
        id: settings
        storagePath: Qt.resolvedUrl("test.ini")
    }
    SakuraMotion {
        id: animation
        config: settings.config
        origins: () => [{x: 100, y: 70, side: -1}, {x: 560, y: 74, side: 1}]
    }
    SakuraBranch { x: 15; y: 40; rightBranch: false; growth: animation.unfold; sway: animation.shake }
    SakuraBranch { x: 440; y: 40; rightBranch: true; growth: animation.unfold; sway: animation.shake }
    SakuraPetalField { id: field; anchors.fill: parent; motion: animation }
    Image { id: blossom; visible: false; source: "art/sakura-blossom.svg" }
    Image { id: petal; visible: false; source: "art/sakura-petal-fall.svg" }

    TestCase {
        name: "SakuraDecoration"
        when: windowShown
        function test_cycles() {
            tryCompare(blossom, "status", Image.Ready)
            tryCompare(petal, "status", Image.Ready)
            compare(settings.config.count, 8)
            verify(!settings.edit("count", 21))
            compare(settings.config.count, 8)
            verify(settings.edit("wind", .64))
            verify(settings.edit("fall", 1500))
            for (let cycle = 0; cycle < 30; cycle++) {
                animation.start()
                compare(field.count, 0)
                tryCompare(field, "count", 8, 1100)
                if (cycle % 5 === 0) {
                    animation.start()
                    compare(field.count, 0)
                    tryCompare(field, "count", 8, 1100)
                }
                animation.stop()
                compare(field.count, 0)
                compare(animation.active, false)
                compare(animation.shake, 0)
            }
            animation.start()
            tryCompare(field, "count", 8, 1100)
            tryCompare(field, "count", 0, 3100)
            tryCompare(animation, "active", false)
            compare(animation.unfold, 1)
            verify(settings.edit("animation", false))
            animation.start()
            compare(animation.active, false)
            verify(settings.edit("animation", true))
            verify(settings.edit("enabled", false))
            animation.start()
            compare(animation.active, false)
            verify(settings.edit("enabled", true))
        }
        function test_limits() {
            const seeds = [{x: 100, y: 70, side: -1}, {x: 560, y: 74, side: 1}]
            compare(Sakura.particles(seeds, Sakura.read({count: 0})).length, 0)
            const particles = Sakura.particles(seeds, Sakura.read({count: 20, fall: 2500}))
            compare(particles.length, 20)
            verify(particles.every(p => p.life >= 1500 && p.life <= 2500))
            verify(particles.every((p, i) => p.x === seeds[i % 2].x))
            verify(particles[0].delay !== particles[1].delay)
        }
        function test_restart() {
            compare(settings.config.wind, .64)
            compare(settings.config.fall, 1500)
            compare(settings.config.enabled, true)
        }
    }
}
