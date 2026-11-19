import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
CheckBox {
 id:control
 implicitHeight:Math.max(34,contentItem.implicitHeight+8);implicitWidth:text.length ? 180 : 28;Layout.minimumWidth:0;Layout.fillWidth:text.length>0;spacing:8;font.pixelSize:13
 leftPadding:0;rightPadding:0
 indicator:Rectangle {
  x:control.leftPadding;y:(control.height-height)/2;width:20;height:20;radius:5
  color:control.checked ? "#71384d" : "#242126";border.color:control.visualFocus ? "#bc7186" : "#67505c"
  Text {anchors.centerIn:parent;text:control.checked ? "✓" : "";font.pixelSize:14;color:control.enabled ? "#f4e9ee" : "#93828b"}
 }
 contentItem:Text {text:control.text;font:control.font;color:control.enabled ? "#ded5da" : "#877b83";leftPadding:28;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap}
}
