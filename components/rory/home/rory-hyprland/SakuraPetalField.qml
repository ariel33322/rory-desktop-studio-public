pragma ComponentBehavior: Bound
import QtQuick

Item {
    id:field
    required property var motion
    readonly property int count:petals.count
    anchors.fill:parent
    clip:true
    enabled:false
    Repeater {
        id:petals
        model:field.motion.particles
        Image {
            required property var modelData
            readonly property real elapsed:field.motion.elapsed-modelData.delay
            readonly property real phase:Math.max(0,Math.min(1,elapsed/modelData.life))
            visible:elapsed>=0 && phase<1
            width:modelData.size;height:width*1.45
            x:modelData.x+modelData.drift*(phase+Math.sin(phase*5+modelData.phase)*phase*.18)-width/2
            y:modelData.y+modelData.drop*(.42*phase+.58*phase*phase)-height/2
            rotation:modelData.rotation*phase+Math.sin(phase*7+modelData.phase)*13
            opacity:Math.min(1,phase*12,(1-phase)*4)*.88
            source:"art/sakura-petal-fall.svg"
            fillMode:Image.PreserveAspectFit
        }
    }
}
