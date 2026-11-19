pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
ColumnLayout {
 id:section
 required property string title
 property bool expanded:true
 property bool headerVisible:true
 default property alias content:body.data
 Layout.fillWidth:true;spacing:10
 data:[
  StudioButton {visible:section.headerVisible;Layout.fillWidth:true;text:(section.expanded ? "▾  " : "▸  ")+section.title;onClicked:section.expanded=!section.expanded},
  ColumnLayout {id:body;Layout.fillWidth:true;visible:section.expanded || !section.headerVisible;spacing:10}
 ]
}
