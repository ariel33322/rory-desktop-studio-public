pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: control
    property bool selected: false
    property string hint: ""
    property string glyph: ""
    property color glyphInk: "#e290a4"
    property real glyphLevel: 1
    property bool glyphOff: false
    property bool flat: false
    property bool workspaceStyle: false
    property bool glyphCharging: false
    property int glyphSize: 16
    property color ink: "#f4e8eb"
    property int textSize: 12
    property bool alignLeft: false
    implicitWidth: Math.max(32, label.implicitWidth + icon.width + (glyph && text ? 5 : 0) + 18)
    implicitHeight: 32
    hoverEnabled: true
    padding: 9
    Accessible.name: hint || text
    ToolTip.visible: flat && hovered && hint !== ""
    ToolTip.delay: 450
    ToolTip.text: hint

    background: Rectangle {
        radius: control.workspaceStyle ? 10 : 6
        color: control.down ? "#572033"
            : control.selected ? (control.workspaceStyle ? "#a4142a" : "#421725")
            : control.hovered ? "#34212a" : control.workspaceStyle ? "#10090e"
            : control.flat ? "transparent" : "#211820"
        border.width: 1
        border.color: control.selected || control.activeFocus ? "#ba4255"
            : control.workspaceStyle ? "#9b182c"
            : control.flat && !control.hovered ? "transparent" : "#51303e"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Item {
        RoryGlyph {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            x: control.text ? 0 : (parent.width - width) / 2
            width: control.glyph ? control.glyphSize : 0
            height: control.glyphSize
            visible: width > 0
            kind: control.glyph
            ink: control.enabled ? control.glyphInk : "#a599a2"
            level: control.glyphLevel
            off: control.glyphOff
            charging: control.glyphCharging
        }

        Text {
            id: label
            anchors.fill: parent
            anchors.leftMargin: icon.width + (control.glyph && control.text ? 5 : 0)
            text: control.text
            font.pixelSize: control.textSize
            font.weight: control.selected ? Font.DemiBold : Font.Normal
            color: control.enabled ? control.ink : "#a599a2"
            elide: Text.ElideRight
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: control.alignLeft ? Text.AlignLeft : Text.AlignHCenter
        }
    }
}
