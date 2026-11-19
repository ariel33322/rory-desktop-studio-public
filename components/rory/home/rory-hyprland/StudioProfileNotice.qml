pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:panel
 required property var manager
 objectName:"profileNotice"
 visible:!!manager.pendingChange || manager.pendingDelete!=="" || manager.pendingSave!=="" || !!manager.pendingLink || manager.error!==""
 Label {Layout.fillWidth:true;visible:panel.manager.error!=="";text:panel.manager.error;color:"#efb0c0";wrapMode:Text.WordWrap}
 StudioSection {title:"Cambio pendiente";expanded:true;visible:!!panel.manager.pendingChange
  Label {Layout.fillWidth:true;color:"#efc3cf";wrapMode:Text.WordWrap;text:panel.manager.pendingChange ? "Hay cambios sin guardar. Destino: «"+panel.manager.profileName(panel.manager.pendingChange.id)+"»"+(panel.manager.pendingChange.source==="wallpaper" ? " · por el fondo seleccionado" : "") : ""}
  Flow {Layout.fillWidth:true;spacing:6
   StudioButton {objectName:"saveAndSwitch";text:"Guardar y cambiar";enabled:!!panel.manager.activeProfile || panel.manager.count<20;onClicked:panel.manager.resolvePending("save")}
   StudioButton {objectName:"discardAndSwitch";text:"Descartar y cambiar";onClicked:panel.manager.resolvePending("discard")}
   StudioButton {objectName:"cancelProfileSwitch";text:"Cancelar";onClicked:panel.manager.resolvePending("cancel")}
  }
  Label {Layout.fillWidth:true;color:"#bca7b1";font.pixelSize:11;wrapMode:Text.WordWrap;text:panel.manager.pendingChange && panel.manager.pendingChange.beforeWallpaper ? "Cancelar conserva el fondo y la composición actuales." : "Cancelar conserva la composición y el fondo que ya está aplicado."}
 }
 // Deletion is modal and centered in the window, not inside the scrolled inspector.
 readonly property QtObject deleteUi:QtObject {
  readonly property Dialog dialog:Dialog {
   id:deleteDialog;objectName:"profileDeleteDialog"
   parent:panel.Overlay.overlay
   visible:panel.manager.pendingDelete!==""
   modal:true;focus:true;closePolicy:Popup.CloseOnEscape
   width:Math.min(440,parent ? Math.max(240,parent.width-24) : 440)
   height:Math.min(implicitHeight,parent ? Math.max(160,parent.height-24) : implicitHeight)
   x:parent ? Math.max(8,(parent.width-width)/2) : 0
   y:parent ? Math.max(8,(parent.height-height)/2) : 0
   padding:16
   background:Rectangle {radius:9;color:"#292229";border.color:"#975069"}
   header:Label {text:"Eliminar perfil";padding:16;color:"#f0dce7";font.pixelSize:18;font.bold:true}
   onRejected:panel.manager.confirmDelete(false)
   contentItem:ScrollView {
    id:deleteScroll;implicitHeight:deleteContent.implicitHeight;contentWidth:availableWidth;clip:true
    ColumnLayout {id:deleteContent;width:deleteScroll.availableWidth;spacing:12
     Label {objectName:"deleteProfileExactName";Layout.fillWidth:true;text:"¿Eliminar «"+panel.manager.pendingDeleteName+"»?";textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;color:"#f2dfe8";font.pixelSize:15}
     Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#cab0bd";text:"Se quitarán sus "+panel.manager.linkedWallpapers(panel.manager.pendingDelete).length+" vínculos. Las imágenes y los demás perfiles se conservan."}
     Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#cbb4bf";text:panel.manager.deletingActive ? "Después se cargará «"+panel.manager.profileName(panel.manager.deleteFallbackId)+"»." : "El perfil activo y su composición no cambiarán.";textFormat:Text.PlainText}
     Label {visible:panel.manager.deleteNeedsDecision;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#f0b6c6";text:"Hay cambios sin guardar. Puedes conservarlos en un perfil nuevo antes de eliminar éste, o descartarlos explícitamente."}
     Label {visible:panel.manager.error!=="";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#f0acbe";text:panel.manager.error;textFormat:Text.PlainText}
     Label {visible:!panel.manager.deleteRequestCurrent;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#f0acbe";text:"La selección o el perfil cambiaron. Cancela y vuelve a solicitar la eliminación."}
     ColumnLayout {Layout.fillWidth:true;spacing:6
      StudioButton {objectName:"confirmDeleteProfile";visible:!panel.manager.deleteNeedsDecision;text:"Eliminar perfil";enabled:panel.manager.deleteRequestCurrent && panel.manager.canDeleteProfile(panel.manager.pendingDelete);onClicked:panel.manager.confirmDelete(true)}
      StudioButton {objectName:"saveCopyAndDeleteProfile";visible:panel.manager.deleteNeedsDecision;text:"Guardar copia y eliminar";enabled:panel.manager.deleteRequestCurrent && panel.manager.canDeleteProfile(panel.manager.pendingDelete);onClicked:panel.manager.confirmDelete(true,"save-copy")}
      StudioButton {objectName:"discardAndDeleteProfile";visible:panel.manager.deleteNeedsDecision;text:"Descartar y eliminar";enabled:panel.manager.deleteRequestCurrent && panel.manager.canDeleteProfile(panel.manager.pendingDelete);onClicked:panel.manager.confirmDelete(true,"discard")}
      StudioButton {objectName:"cancelDeleteProfile";text:"Cancelar";onClicked:panel.manager.confirmDelete(false)}
     }
     Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#ab929f";font.pixelSize:11;text:"La eliminación del catálogo no se revierte con el historial visual. Ese historial conserva las configuraciones, sin referencias al perfil eliminado."}
    }
   }
  }
 }
 StudioSection {title:"Reemplazar perfil guardado";visible:panel.manager.pendingSave!==""
  Label {Layout.fillWidth:true;color:"#efc3cf";wrapMode:Text.WordWrap;text:"¿Reemplazar «"+panel.manager.profileName(panel.manager.pendingSave)+"» por la composición actual?"}
  Flow {Layout.fillWidth:true;spacing:6;StudioButton {text:"Reemplazar";onClicked:panel.manager.confirmSave(true)}StudioButton {text:"Cancelar";onClicked:panel.manager.confirmSave(false)}}
 }
 StudioSection {title:"Reasignar fondo";visible:!!panel.manager.pendingLink
  Label {Layout.fillWidth:true;color:"#efc3cf";wrapMode:Text.WordWrap;text:panel.manager.pendingLink ? "Este fondo pertenece a «"+panel.manager.profileName(panel.manager.pendingLink.previous)+"». ¿Vincularlo a «"+panel.manager.profileName(panel.manager.pendingLink.id)+"»?" : ""}
  Flow {Layout.fillWidth:true;spacing:6;StudioButton {objectName:"confirmWallpaperLink";text:"Mover vínculo";onClicked:panel.manager.confirmLink(true)}StudioButton {text:"Cancelar";onClicked:panel.manager.confirmLink(false)}}
 }
}
