pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "WallpaperIdentity.js" as Wallpaper
ColumnLayout {
 id:panel
 required property var manager
 property string linkTargetId:manager.activeId || manager.selectedId
 readonly property string targetId:manager.catalog && manager.catalog.order.indexOf(linkTargetId)>=0 ? linkTargetId : manager.activeId
 readonly property string wallpaperOwner:manager.catalog && manager.wallpaperKey ? manager.catalog.wallpapers[manager.wallpaperKey] || "" : ""
 Connections {target:panel.manager;function onActiveIdChanged(){panel.linkTargetId=panel.manager.activeId}
  function onCatalogChanged(){if(panel.manager.catalog && panel.manager.catalog.order.indexOf(panel.linkTargetId)<0)panel.linkTargetId=panel.manager.activeId || panel.manager.catalog.order[0] || ""}}
 Label {Layout.fillWidth:true;color:"#cda3b5";font.pixelSize:17;font.bold:true;text:"Vínculos con perfiles";wrapMode:Text.WordWrap}
 Label {Layout.fillWidth:true;color:"#c7b3bf";wrapMode:Text.WordWrap;text:"Fondo actual: "+(panel.wallpaperOwner ? panel.manager.profileName(panel.wallpaperOwner) : "sin perfil vinculado")}
 Label {Layout.fillWidth:true;visible:panel.wallpaperOwner!=="" && panel.wallpaperOwner!==panel.manager.activeId;color:"#e2b0c0";wrapMode:Text.WordWrap;text:"La composición actual es distinta del vínculo del fondo. Cambiar de perfil manualmente no cambia la imagen."}
 StudioButton {objectName:"applyWallpaperProfile";visible:panel.wallpaperOwner!=="" && panel.wallpaperOwner!==panel.manager.activeId;Layout.fillWidth:true;text:"Aplicar el perfil vinculado";onClicked:panel.manager.activateProfile(panel.wallpaperOwner)}
 StudioSection {title:"Perfil destino del vínculo";expanded:false
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bca5b1";font.pixelSize:11;text:"Administración de enlaces: elegir aquí no carga la figura. El perfil activo se cambia en la cabecera."}
  StudioCombo {Layout.fillWidth:true;objectName:"linkProfileTarget";model:panel.manager.orderedProfiles.map(profile=>profile.name);currentIndex:panel.manager.catalog ? panel.manager.catalog.order.indexOf(panel.targetId) : -1;onActivated:index=>panel.linkTargetId=panel.manager.catalog.order[index]}
 }
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#cfb2bf";text:"Enlaces de «"+panel.manager.profileName(panel.targetId)+"»"}
 StudioButton {objectName:"linkCurrentWallpaper";Layout.fillWidth:true;Layout.minimumWidth:0;enabled:!!panel.targetId && !!panel.manager.wallpaperKey;text:panel.wallpaperOwner===panel.targetId && panel.targetId ? "Desvincular el fondo actual" : "Vincular el fondo actual";onClicked:{if(panel.wallpaperOwner===panel.targetId)panel.manager.unlinkWallpaper(panel.targetId,panel.manager.wallpaperKey);else panel.manager.linkWallpaper(panel.targetId,panel.manager.settings.imageUrl,false)}}
 Repeater {model:panel.manager.linkedWallpapers(panel.targetId)
  delegate:RowLayout {id:linked;required property string modelData;Layout.fillWidth:true
   Label {Layout.fillWidth:true;Layout.minimumWidth:0;color:"#d6c4ce";font.pixelSize:12;text:Wallpaper.label(linked.modelData);wrapMode:Text.WrapAnywhere}
   StudioToolButton {text:"×";Accessible.name:"Desvincular "+Wallpaper.label(linked.modelData);onClicked:panel.manager.unlinkWallpaper(panel.targetId,linked.modelData)}
  }
 }
 StudioToggle {id:chooseWallpaper;objectName:"chooseLinkedWallpaper";text:"Vincular otra imagen desde la galería";enabled:!!panel.targetId}
 Loader {id:chooser;objectName:"linkedWallpaperChooser";Layout.fillWidth:true;active:chooseWallpaper.checked && !!panel.targetId;visible:active;onActiveChanged:{if(active)setSource(Qt.resolvedUrl("WallpaperPanel.qml"),{settings:panel.manager.settings,selectionOnly:true});else source=""}}
 Connections {target:chooser.item;ignoreUnknownSignals:true;function onImageSelected(url){panel.manager.linkWallpaper(panel.targetId,url,false);chooseWallpaper.checked=false}}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#ae98a5";font.pixelSize:11;text:"Una imagen puede vincularse a un solo perfil. Vincular no cambia el fondo ni guarda la composición. Las rutas normalizadas distinguen archivos con el mismo nombre."}
}
