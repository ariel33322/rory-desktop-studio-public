pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "StudioProfiles.js" as Profiles
ColumnLayout {
 id:bar
 required property var manager
 property string nameOwner:""
 property bool nameDirty:false
 property bool renaming:false
 property string nameError:""
 property string menuProfileId:manager.activeId
 objectName:"profileBar"
 spacing:6
 function finishName(){
  if(!nameDirty){renaming=false;return true}
  if(nameOwner!==manager.activeId){cancelName();return true}
  if(!manager.renameProfile(nameOwner,nameInput.text)){nameError=manager.error;return false}
  nameDirty=false;renaming=false;nameError="";nameInput.text=manager.profileName(nameOwner);return true
 }
 function cancelName(){if(nameError && manager.error===nameError)manager.error="";nameDirty=false;renaming=false;nameError="";nameInput.text=manager.activeProfile ? manager.activeProfile.name : "";nameOwner=manager.activeId}
 function activate(id){
  forceActiveFocus()
  if(!finishName()){profilePicker.currentIndex=Qt.binding(()=>manager.catalog ? manager.catalog.order.indexOf(manager.activeId) : -1);return false}
  manager.controller.endTransaction()
  const result=manager.activateProfile(id)
  // QQuickComboBox changes its currentIndex on activation. Restore actual owner.
  profilePicker.currentIndex=Qt.binding(()=>manager.catalog ? manager.catalog.order.indexOf(manager.activeId) : -1)
  return result
 }
 function beginRename(){
  if(!manager.activeProfile)return
  profilePicker.popup.close();nameOwner=manager.activeId;renaming=true;nameInput.forceActiveFocus();nameInput.selectAll()
 }
 function openPicker(){
  if(!finishName())return false
  profilePicker.forceActiveFocus();profilePicker.popup.open();return true
 }
 function create(){forceActiveFocus();if(!finishName())return;const id=manager.createProfile(Profiles.uniqueName(manager.catalog,"Nuevo perfil"));if(id)beginRename()}
 Connections {target:bar.manager;function onActiveIdChanged(){bar.cancelName()}
  function onActiveProfileChanged(){if(!bar.nameDirty)bar.cancelName()}}
 RowLayout {
  Layout.fillWidth:true;spacing:6
  StudioCombo {
   id:profilePicker;objectName:"managedProfileList";Layout.fillWidth:true;Layout.minimumWidth:90
   enabled:bar.manager.ready && bar.manager.count>0
   model:bar.manager.orderedProfiles.map(profile=>profile.name)
   currentIndex:bar.manager.catalog ? bar.manager.catalog.order.indexOf(bar.manager.activeId) : -1
   Accessible.name:"Perfil activo · elegir y cargar"
   ToolTip.visible:hovered && !bar.renaming;ToolTip.text:"Clic: abrir perfiles · Doble clic o F2: renombrar"
   contentItem:StudioField {
    id:nameInput;objectName:"managedProfileName";leftPadding:0;rightPadding:0;maximumLength:80
    readOnly:!bar.renaming;selectByMouse:bar.renaming
    placeholderText:"Sin perfil · elige o crea";text:bar.manager.activeProfile ? bar.manager.activeProfile.name : ""
    background:Item {}
    Accessible.name:bar.renaming ? "Renombrar perfil activo" : "Nombre del perfil activo · abrir lista"
    onActiveFocusChanged:if(activeFocus && bar.renaming)bar.nameOwner=bar.manager.activeId
    onTextEdited:{bar.nameDirty=true;bar.nameOwner=bar.manager.activeId;bar.nameError=""}
    onEditingFinished:if(bar.renaming)bar.finishName()
    Keys.onEscapePressed:event=>{if(profilePicker.popup.visible)profilePicker.popup.close();else bar.cancelName();event.accepted=true}
    Keys.onPressed:event=>{
     if(event.key===Qt.Key_F2){bar.beginRename();event.accepted=true}
     else if(!bar.renaming && [Qt.Key_Space,Qt.Key_Return,Qt.Key_Enter,Qt.Key_Down].indexOf(event.key)>=0){bar.openPicker();event.accepted=true}
    }
    MouseArea {objectName:"profileNameHitArea";anchors.fill:parent;enabled:!bar.renaming;onClicked:bar.openPicker();onDoubleClicked:bar.beginRename()}
   }
   indicator:Item {
    x:profilePicker.width-30;width:30;height:profilePicker.height
    Text {anchors.centerIn:parent;text:"▾";color:"#bb879b";font.pixelSize:14}
    MouseArea {objectName:"profileArrowHitArea";anchors.fill:parent;onClicked:bar.openPicker()}
   }
   Keys.onPressed:event=>{if(event.key===Qt.Key_F2){bar.beginRename();event.accepted=true}}
   popup.width:Math.min(340,bar.width)
   delegate:ItemDelegate {
    id:profileOption;required property var modelData;required property int index;width:profilePicker.popup.width-10;height:36
    highlighted:profilePicker.highlightedIndex===index
    contentItem:Text {text:String(profileOption.modelData);color:"#eadde5";font.pixelSize:13;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    background:Rectangle {radius:4;color:profileOption.highlighted ? "#58313f" : "#272228"}
   }
   onActivated:index=>bar.activate(bar.manager.catalog.order[index])
  }


  StudioToolButton {id:profileMenuButton;objectName:"profileMenuButton";text:"⋯";Accessible.name:"Opciones del perfil";ToolTip.visible:hovered;ToolTip.text:"Guardar y administrar perfiles";onClicked:{bar.forceActiveFocus();if(bar.finishName())profileMenu.popup(bar,profileMenuButton.x,profileMenuButton.y+profileMenuButton.height)}}
 }
 RowLayout {Layout.fillWidth:true
  Label {Layout.fillWidth:true;Layout.minimumWidth:0;wrapMode:Text.WordWrap;font.pixelSize:11;color:bar.nameError ? "#efacbc" : "#bea8b3";text:bar.nameError || (bar.manager.count+"/20 · "+(bar.manager.activeProfile ? bar.manager.dirty ? "Modificado · perfil sin actualizar" : "Perfil guardado" : bar.manager.dirty ? "Borrador sin perfil" : "Configuración sin perfil"))}
 }

 readonly property var actionsMenu:profileMenu
 StudioMenu {
  id:profileMenu;objectName:"profileActionsMenu"
  implicitWidth:310
  onAboutToShow:bar.menuProfileId=bar.manager.activeId
  StudioMenuItem {objectName:"saveManagedProfile";text:"Guardar";visible:!!bar.manager.activeProfile;enabled:visible;onTriggered:{bar.forceActiveFocus();if(bar.finishName()){bar.manager.controller.endTransaction();bar.manager.saveProfile(bar.manager.activeId,false)}}}
  StudioMenuItem {objectName:"saveAsNewProfile";text:"Guardar como nuevo";enabled:bar.manager.ready && bar.manager.count<20;onTriggered:bar.create()}
  StudioMenuItem {objectName:"renameProfile";text:"Renombrar";enabled:!!bar.manager.activeProfile;onTriggered:bar.beginRename()}
  StudioMenuItem {text:"Eliminar perfil";objectName:"deleteProfile";enabled:bar.manager.canDeleteProfile(bar.menuProfileId);onTriggered:bar.manager.requestDelete(bar.menuProfileId)}
  StudioMenuItem {
   visible:!!bar.menuProfileId && !bar.manager.canDeleteProfile(bar.menuProfileId);enabled:false;height:visible ? implicitHeight : 0
   implicitHeight:Math.max(36,contentItem.implicitHeight+12)
   contentItem:Text {width:profileMenu.width-26;text:bar.manager.deleteBlockReason(bar.menuProfileId);textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#c7a5b3";font.pixelSize:11}
  }
  MenuSeparator {}
  StudioMenuItem {objectName:"duplicateProfile";text:"Duplicar";enabled:!!bar.manager.activeProfile && bar.manager.count<20;onTriggered:{if(!bar.finishName())return;bar.manager.duplicateProfile(bar.manager.activeId)}}
  StudioMenuItem {objectName:"revertProfile";text:"Revertir…";enabled:!!bar.manager.activeProfile && bar.manager.dirty;onTriggered:{bar.forceActiveFocus();bar.manager.requestLoad(bar.manager.activeId,"revert","")}}

 }
 Component.onCompleted:cancelName()
}
