import QtQuick
import QtQuick.Controls
Switch {
    id: control
    implicitWidth: 48; implicitHeight: 28
    padding: 0
    indicator: Rectangle {
        implicitWidth: 46; implicitHeight: 26; radius: 13
        y: (control.height-height)/2
        color: control.checked ? "#c30f30" : "#362a30"
        border.color: control.checked ? "#ef3856" : "#67505a"
        Rectangle {
            width: 20; height: 20; radius: 10; y: 3
            x: control.checked ? 23 : 3; color: "#ffe7e9"
            Behavior on x { NumberAnimation { duration: 110 } }
        }
    }
}
