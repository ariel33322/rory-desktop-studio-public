import QtQuick
import QtQuick.Controls
import "RoryTheme.js" as Theme
Switch {
    id: control
    property string theme:"crimson"
    implicitWidth: 48; implicitHeight: 28
    padding: 0
    indicator: Rectangle {
        implicitWidth: 46; implicitHeight: 26; radius: 13
        y: (control.height-height)/2
        color: control.checked ? Theme.tone(control.theme,"#c30f30",Theme.fuchsia) : "#362a30"
        border.color: control.checked ? Theme.tone(control.theme,"#ef3856",Theme.cherry) : "#67505a"
        Rectangle {
            width: 20; height: 20; radius: 10; y: 3
            x: control.checked ? 23 : 3; color: Theme.tone(control.theme,"#ffe7e9",Theme.text)
            Behavior on x { NumberAnimation { duration: 110 } }
        }
    }
}
