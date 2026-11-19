pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
ComboBox {
 id:control
 implicitHeight:36;implicitWidth:160
 leftPadding:10;rightPadding:30;font.pixelSize:13
 contentItem:Text {text:control.displayText;font:control.font;color:control.enabled ? "#e8dfe4" : "#887981";verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
 indicator:Text {x:control.width-width-11;y:(control.height-height)/2;text:"▾";color:"#b88a9a";font.pixelSize:14}
 background:Rectangle {radius:6;color:control.down ? "#382930" : "#262227";border.color:control.visualFocus ? "#a15a70" : "#503d47"}
 delegate:ItemDelegate {
  id:entry
  required property var modelData
  required property int index
  width:control.width;height:34
  text:control.textRole ? String(modelData[control.textRole]) : String(modelData)
  highlighted:control.highlightedIndex===index
  contentItem:Text {text:entry.text;color:"#eee5ea";font.pixelSize:13;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
  background:Rectangle {radius:4;color:entry.highlighted ? "#58313f" : "#272228"}
 }
 popup:Popup {
  y:control.height+4;width:control.width;padding:5
  implicitHeight:Math.min(contentItem.implicitHeight+10,250)
  contentItem:ListView {clip:true;implicitHeight:contentHeight;model:control.popup.visible ? control.delegateModel : null;currentIndex:control.highlightedIndex;highlightMoveDuration:0;ScrollBar.vertical:ScrollBar{}}
  background:Rectangle {radius:7;color:"#272228";border.color:"#684351"}
 }
}
