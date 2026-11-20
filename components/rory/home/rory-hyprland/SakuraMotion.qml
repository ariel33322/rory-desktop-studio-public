pragma ComponentBehavior: Bound
import QtQuick
import "SakuraDecoration.js" as Sakura

Item {
    id:motion
    width:0;height:0;visible:false
    required property var config
    required property var origins
    property real unfold:1
    property real shake:0
    property real elapsed:0
    property var particles:[]
    readonly property bool active: reveal.running || wind.running || drift.running

    function stop() {
        reveal.stop()
        wind.stop()
        drift.stop()
        unfold=1
        shake=0
        particles=[]
        elapsed=0
    }
    function start() {
        stop()
        if(!config.enabled || !config.animation)return
        unfold=0
        reveal.start()
        wind.start()
    }
    function emitPetals() {
        particles=Sakura.particles(origins(),config)
        if(!particles.length)return
        drift.duration=Math.max(...particles.map(p=>p.delay+p.life))
        drift.restart()
    }
    NumberAnimation {
        id:reveal
        target:motion;property:"unfold";from:0;to:1;duration:470
        easing.type:Easing.OutCubic
    }
    SequentialAnimation {
        id:wind
        PauseAnimation {duration:340}
        NumberAnimation {target:motion;property:"shake";to:.95;duration:130;easing.type:Easing.OutSine}
        ScriptAction {script:motion.emitPetals()}
        NumberAnimation {target:motion;property:"shake";to:-.27;duration:155;easing.type:Easing.InOutSine}
        NumberAnimation {target:motion;property:"shake";to:0;duration:180;easing.type:Easing.OutSine}
    }
    NumberAnimation {
        id:drift
        target:motion;property:"elapsed";from:0;to:duration
        onFinished:{motion.particles=[];motion.elapsed=0}
    }
}
