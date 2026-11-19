import QtQuick
import QtQuick.Controls
MenuItem {
 id:control
 implicitHeight:36
 font.pixelSize:13
 Accessible.name:text
 ToolTip.visible:hovered
 ToolTip.text:text
 contentItem:Text {text:control.text;font:control.font;color:control.enabled ? "#e9dfe5" : "#8c7d85";verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight;leftPadding:8;rightPadding:8}
 background:Rectangle {radius:4;color:control.highlighted ? "#57323f" : "transparent"}
}
