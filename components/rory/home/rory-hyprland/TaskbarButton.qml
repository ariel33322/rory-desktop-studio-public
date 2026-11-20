pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Button {
    id: button
    required property var config
    property string glyph: ""
    property url iconSource: ""
    property string description: text
    property bool selected: false
    hoverEnabled: true
    Accessible.name: description
    ToolTip.text: description
    ToolTip.visible: hovered && description !== ""
    ToolTip.delay: 650
    leftPadding: 6
    rightPadding: 6
    topPadding: 3
    bottomPadding: 3
    contentItem: Row {
        spacing: 4
        Image {
            id: icon
            visible: status===Image.Ready
            source: button.iconSource
            width: button.config.iconSize
            height: width
            fillMode: Image.PreserveAspectFit
        }
        Text {
            text: (button.glyph && icon.status!==Image.Ready ? button.glyph+" " : "")+button.text
            color: button.text ? button.config.textColor : button.config.iconColor
            font.pixelSize: button.text ? button.config.textSize : button.config.iconSize-4
            width: Math.min(190,implicitWidth)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
        }
    }
    background: Rectangle {
        radius: Math.min(6,button.config.radius)
        color: button.down || button.selected ? button.config.activeColor : button.hovered ? "#604457" : "transparent"
        Behavior on color { ColorAnimation { duration: button.config.duration } }
    }
}
