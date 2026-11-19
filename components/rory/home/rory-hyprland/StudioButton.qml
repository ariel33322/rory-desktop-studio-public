import QtQuick
import QtQuick.Controls
Button {
 id:control
 implicitHeight:34;implicitWidth:Math.max(76,implicitContentWidth+22)
 leftPadding:11;rightPadding:11
 hoverEnabled:true;font.pixelSize:13
 contentItem:Text {text:control.text;font:control.font;color:control.enabled ? "#ece4e7" : "#81757c";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
 background:Rectangle {radius:6;color:!control.enabled ? "#221f23" : control.down || control.checked ? "#58303f" : control.hovered ? "#3b2b33" : "#2c252c";border.color:control.visualFocus ? "#a15c70" : control.checked ? "#8d485e" : "#4c3943";border.width:1}
}
