pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Wallpaper conflicts do not navigate away from the gallery or open an editor.
PanelWindow {
    id:prompt
    required property ShellScreen modelData
    required property var associations
    required property var studio
    property bool requested:false
    screen:modelData
    visible:(!!associations.pending || requested)
        && modelData===(studio.targetScreen || Quickshell.screens[0])
    anchors {top:true;bottom:true;left:true;right:true}
    color:"transparent"
    WlrLayershell.namespace:"rory-wallpaper-confirmation"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask:Region {item:card}
    function cancel(){requested=false;associations.resolve("cancel");associations.error=""}
    function clearResolved(){if(!associations.pending && associations.error==="")requested=false}
    Connections {
        target:prompt.associations
        function onAttentionRequired(){prompt.requested=true}
        function onPendingChanged(){prompt.clearResolved()}
        function onErrorChanged(){prompt.clearResolved()}
    }
    Rectangle {
        id:card
        anchors.centerIn:parent
        width:Math.max(1,Math.min(540,prompt.width-24))
        height:Math.max(1,Math.min(content.implicitHeight+32,prompt.height-32))
        color:"#fa1c191e";radius:10;border.color:"#975069"
        ScrollView {
            id:scroll;anchors.fill:parent;anchors.margins:16;clip:true;contentWidth:availableWidth
            ColumnLayout {
                id:content;width:scroll.availableWidth;spacing:12
                RowLayout {Layout.fillWidth:true
                    Label {Layout.fillWidth:true;text:"Aplicar wallpaper";color:"#f0e6eb";font.pixelSize:18;font.bold:true}
                    StudioToolButton {text:"×";onClicked:prompt.cancel()}
                }
                StudioAssociationNotice {Layout.fillWidth:true;manager:prompt.associations}
            }
        }
    }
    Shortcut {sequence:"Escape";context:Qt.WindowShortcut;onActivated:prompt.cancel()}
}
