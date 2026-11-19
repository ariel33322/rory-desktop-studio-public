import QtQuick
import QtQuick.Controls
TextField {
 id:control
 implicitHeight:34;implicitWidth:96
 color:enabled ? "#ece7e9" : "#877e83"
 placeholderTextColor:"#95878e"
 selectionColor:"#743449";selectedTextColor:"#fff6f8"
 font.pixelSize:14
 leftPadding:10;rightPadding:10
 background:Rectangle {radius:6;color:control.enabled ? "#242126" : "#201e22";border.width:1;border.color:control.activeFocus ? "#a05a6d" : "#443840"}
}
