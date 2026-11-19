pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:launcher
    required property ShellScreen modelData
    required property var studio
    required property var associations
    screen:modelData
    anchors {top:true;bottom:true;left:true;right:true}
    visible:studio.page!=="" && modelData===studio.targetScreen
    color:"transparent"
    WlrLayershell.namespace:"rory-studio-launcher"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask:Region {item:card;Region {item:card.Overlay.overlay && card.Overlay.overlay.visible ? card.Overlay.overlay : null}}
    Rectangle {
        id:card
        anchors.centerIn:parent
        width:Math.max(1,Math.min(620,launcher.width-24))
        height:Math.max(1,Math.min(820,launcher.height-48))
        color:"#f51c191e";radius:10;border.color:"#6b3e4d"
        ColumnLayout {
            anchors.fill:parent;anchors.margins:16;spacing:12
            RowLayout {
                Layout.fillWidth:true
                Label {Layout.fillWidth:true;text:"Rory Desktop Studio";color:"#f0e6eb";font.pixelSize:20;font.bold:true;elide:Text.ElideRight}
                StudioToolButton {text:"×";Accessible.name:"Cerrar Studio";onClicked:launcher.studio.close()}
            }
            StudioNavigation {Layout.fillWidth:true;studio:launcher.studio;targetScreen:launcher.modelData;destination:launcher.studio.page}
            ScrollView {
                id:scroll
                Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ColumnLayout {
                    width:scroll.availableWidth;spacing:14
                    Label {
                        Layout.fillWidth:true
                        visible:launcher.studio.page==="home"
                        text:"Selecciona un editor en el menú desplegable."
                        color:"#c7b3bf"
                    }
                    StudioWallpaperWorkspace {
                        Layout.fillWidth:true
                        visible:launcher.studio.page==="wallpapers"
                        settings:launcher.studio.wallpaperSettings
                        manager:launcher.associations
                        showAssociations:false
                    }
                    StudioAssociationsPanel {
                        Layout.fillWidth:true
                        visible:launcher.studio.page==="associations"
                        manager:launcher.associations
                    }
                    Loader {
                        Layout.fillWidth:true;active:launcher.studio.page==="settings";visible:active
                        sourceComponent:ColumnLayout {
                            Label {text:"Configuración general";color:"#eadce5";font.pixelSize:18;font.bold:true}
                            StudioShortcutPanel {Layout.fillWidth:true;studio:launcher.studio}
                            StudioToggle {text:"Usar el atajo existente de Studio para el lanzador";checked:launcher.studio.centralShortcut;onToggled:launcher.studio.centralShortcut=checked}
                            Label {Layout.fillWidth:true;text:"Actívalo después de probar el menú. Reutiliza el enlace que llama a toggleAudioEditor. Puedes comprobar y cambiar su combinación arriba. Los IPC originales siguen disponibles.";color:"#bea8b3";font.pixelSize:12;wrapMode:Text.WordWrap}
                        }
                    }
                }
            }
        }
    }
    Shortcut {sequence:"Escape";context:Qt.WindowShortcut;onActivated:launcher.studio.close()}
}
