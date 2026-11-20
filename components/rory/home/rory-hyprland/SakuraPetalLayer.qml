pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:layer
    required property ShellScreen output
    required property var motion
    screen:output
    anchors {top:true;left:true;right:true}
    implicitHeight: Math.min(350, output?.height ?? 350)
    exclusionMode:ExclusionMode.Ignore
    WlrLayershell.layer:WlrLayer.Bottom
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    WlrLayershell.namespace:"rory-sakura-petals"
    mask:Region {width:0;height:0}
    color:"transparent"
    visible:!!output && motion.particles.length>0
    SakuraPetalField {anchors.fill:parent;motion:layer.motion}
}
