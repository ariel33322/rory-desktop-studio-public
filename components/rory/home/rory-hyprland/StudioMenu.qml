import QtQuick
import QtQuick.Controls
Menu {
 padding:5
 margins:6
 width:Math.min(implicitWidth,Math.max(160,parent ? parent.width-12 : implicitWidth))
 background:Rectangle {color:"#29232a";radius:7;border.color:"#704653"}
}
