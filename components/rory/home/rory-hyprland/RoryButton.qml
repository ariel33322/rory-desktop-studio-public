pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "RoryTheme.js" as Theme

AbstractButton {
    id: control
    property string theme:"crimson"
    function tone(original,pink){return Theme.tone(theme,original,pink)}
    property bool selected: false
    property string hint: ""
    property bool tooltipEnabled:true
    property string glyph: ""
    property color glyphInk: control.tone("#e290a4","#FF9DC3")
    property real glyphLevel: 1
    property bool glyphOff: false
    property bool flat: false
    property bool workspaceStyle: false
    property bool glyphCharging: false
    property int glyphSize: 16
    property color ink: control.tone("#f4e8eb","#F7C7DA")
    property int textSize: 12
    property bool alignLeft: false
    implicitWidth: Math.max(32, label.implicitWidth + icon.width + (glyph && text ? 5 : 0) + 18)
    implicitHeight: 32
    hoverEnabled: true
    padding: 9
    Accessible.name: hint || text
    ToolTip.visible: tooltipEnabled && flat && hovered && hint !== ""
    ToolTip.delay: 450
    ToolTip.text: hint

    background: Rectangle {
        radius: control.workspaceStyle ? 10 : 6
        color: control.down ? control.tone("#572033","#71334F")
            : control.selected ? (control.workspaceStyle ? control.tone("#a4142a","#9D215B") : control.tone("#421725","#5A2142"))
            : control.hovered ? control.tone("#34212a","#422238") : control.workspaceStyle ? control.tone("#10090e","#120B14")
            : control.flat ? "transparent" : control.tone("#211820","#25101E")
        border.width: 1
        border.color: control.selected || control.activeFocus ? control.tone("#ba4255","#FF5B9A")
            : control.workspaceStyle ? control.tone("#9b182c","#C63B76")
            : control.flat && !control.hovered ? "transparent" : control.tone("#51303e","#873556")
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
            ink: control.enabled ? control.glyphInk : control.tone("#a599a2","#A88499")
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
            color: control.enabled ? control.ink : control.tone("#a599a2","#A88499")
            elide: Text.ElideRight
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: control.alignLeft ? Text.AlignLeft : Text.AlignHCenter
        }
    }
}
