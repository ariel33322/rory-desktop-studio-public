pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id:workspace
    required property WallpaperSettings settings
    required property var manager
    property bool showAssociations:true
    property int initialPage:0
    property int page:initialPage
    RowLayout {Layout.fillWidth:true;spacing:6
        StudioButton {objectName:"wallpaperApplyTab";Layout.fillWidth:true;text:"Aplicar fondo";checkable:true;checked:workspace.page===0;onClicked:workspace.page=0}
        StudioButton {objectName:"wallpaperConfigureTab";Layout.fillWidth:true;text:"Configurar";checkable:true;checked:workspace.page===1;onClicked:workspace.page=1}
        StudioButton {objectName:"wallpaperAssociationsTab";visible:workspace.showAssociations;Layout.fillWidth:true;text:"Vincular perfiles";checkable:true;checked:workspace.page===2;onClicked:workspace.page=2}
    }
    // Keep the association form alive while switching pages, preserving its unsubmitted fields.
    Loader {Layout.fillWidth:true;visible:workspace.page===0;sourceComponent:WallpaperPanel {settings:workspace.settings;showStudioActions:false}}
    Loader {Layout.fillWidth:true;visible:workspace.page===1;sourceComponent:WallpaperConfigurationPanel {settings:workspace.settings}}
    Loader {
        Layout.fillWidth:true
        active:workspace.showAssociations
        visible:active && workspace.page===2
        sourceComponent:StudioAssociationsPanel {manager:workspace.manager}
    }
}
