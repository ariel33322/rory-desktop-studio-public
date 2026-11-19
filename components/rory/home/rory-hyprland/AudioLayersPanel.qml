pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import "AudioLayers.js" as Layers
ColumnLayout {
 id:panel
 required property var controller
 required property var settings
 property string selectedId:"main"
 property bool sharedSelected:false
 property int sharedPointSelection:0
 property bool sharedPointsVisible:false
 readonly property var document:controller.document
 readonly property string currentId:document && document.order.indexOf(selectedId)>=0 ? selectedId : "main"
 readonly property var selectedLayer:document ? Layers.findV2(document,currentId) || Layers.findV2(document,"main") || Layers.layerV2("main") : Layers.layerV2("main")
 readonly property var types:["bars","particles","waves"]
 property string menuId:"main"
 property string menuName:""
 property string menuDocument:""
 property string menuOwner:""
 property string layerActionMessage:""
 readonly property var hostWindow:Window.window
 readonly property bool menuTargetCurrent:!!document && document.layers.some(layer=>layer.id===menuId)
     && menuOwner===String(controller.activeManagedProfileId || "") && menuDocument===JSON.stringify(document)
 readonly property bool canDeleteMenuLayer:menuTargetCurrent && menuId!=="main" && document.layers.length>1
 readonly property string deleteReason:!menuTargetCurrent ? "La composición cambió. Vuelve a abrir el menú de la capa." : menuId==="main" ? "La capa principal es obligatoria: el motor necesita al menos una capa." : document.layers.length<2 ? "Debe conservarse al menos una capa." : ""
 VisualizerSlider {
  objectName:"visualizerBarCount";Layout.fillWidth:true;controller:panel.controller
  label:"Número de barras";explanation:"Cantidad base compartida (24–384). Cada capa conserva además su densidad."
  from:24;to:384;value:panel.settings.visualizerBarCount
  onValueEdited:v=>panel.controller.setValue("visualizerBarCount",Math.round(v))
 }
 function openLayerMenu(id,anchor){
  // Use a stable visual parent: pending edits can rebuild the row delegates.
  const at=anchor.mapToItem(panel,0,anchor.height)
  finish()
  if(!document || !document.layers.some(layer=>layer.id===id))return
  menuId=id;menuName=Layers.findV2(document,id).name;menuOwner=String(controller.activeManagedProfileId || "");menuDocument=JSON.stringify(document);layerActionMessage=""
  layerMenu.popup(panel,at.x,at.y)
 }
 function deleteMenuLayer(){
  if(!canDeleteMenuLayer){layerActionMessage=deleteReason;return false}
  const target=menuId,wasShared=sharedSelected,next=currentId===target ? "main" : currentId
  finish()
  if(!canDeleteMenuLayer){layerActionMessage=deleteReason;return false}
  controller.removeLayer(target)
  if(document.layers.some(layer=>layer.id===target))return false
  if(wasShared)selectShared();else select(next)
  return true
 }
 property bool resetPending:false
 property string resetId:"main"
 function finish(){forceActiveFocus();controller.finishPendingInputs();controller.endTransaction();settings.visualizerPointerEditMode=false}
 function select(id){finish();sharedSelected=false;selectedId=id;resetPending=false}
 function selectShared(){finish();sharedSelected=true;resetPending=false}
 function add(duplicate){finish();const id=controller.addLayer(duplicate ? currentId : "");if(id)select(id)}
 function changeType(type){finish();controller.setLayerType(currentId,type)}
 function reorder(id,index){finish();const from=document.order.indexOf(id),target=Math.max(0,Math.min(document.order.length-1,index));if(from<0)return;controller.beginTransaction();for(let n=0;n<Math.abs(target-from);n++)controller.moveLayer(id,target>from ? 1 : -1);controller.endTransaction()}
 onCurrentIdChanged:controller.endTransaction()
 GridLayout {
  Layout.fillWidth:true;columns:width>=720 ? 2 : 1;columnSpacing:18;rowSpacing:14
  ColumnLayout {
   id:list;Layout.fillWidth:panel.width<720;Layout.preferredWidth:panel.width>=720 ? 220 : -1;Layout.maximumWidth:panel.width>=720 ? 240 : Infinity;Layout.alignment:Qt.AlignTop
   RowLayout {Layout.fillWidth:true
    Label {Layout.fillWidth:true;text:"Capas · "+(panel.document ? panel.document.layers.length : 0)+"/4";color:"#cda1b2";font.pixelSize:15;font.bold:true}
    StudioToolButton {objectName:"addLayer";text:"+";Accessible.name:"Añadir capa";enabled:panel.document && panel.document.layers.length<4;onClicked:panel.add(false);ToolTip.visible:hovered;ToolTip.text:"Añadir capa"}
   }
   StudioButton {Layout.fillWidth:true;objectName:"selectSharedGeometry";text:"Figura compartida";checkable:true;checked:panel.sharedSelected;onClicked:panel.selectShared()}
   RowLayout {visible:panel.width<720;Layout.fillWidth:true
    StudioCombo {Layout.fillWidth:true;objectName:"compactLayerSelector";model:["Figura compartida"].concat(panel.document ? panel.document.order.map((id,i)=>(i+1)+" · "+Layers.findV2(panel.document,id).name) : []);currentIndex:panel.sharedSelected ? 0 : panel.document ? panel.document.order.indexOf(panel.currentId)+1 : 0;onActivated:index=>{if(index===0)panel.selectShared();else panel.select(panel.document.order[index-1])}}
    StudioToolButton {visible:!panel.sharedSelected;text:panel.selectedLayer.enabled ? "◉" : "○";Accessible.name:"Visibilidad de capa seleccionada";onClicked:panel.controller.setLayerEnabled(panel.currentId,!panel.selectedLayer.enabled)}
    StudioToolButton {id:compactLayerMenuButton;objectName:"compactLayerMenuButton";visible:!panel.sharedSelected;text:"⋯";Accessible.name:"Opciones de capa seleccionada";onClicked:panel.openLayerMenu(panel.currentId,compactLayerMenuButton)}
   }
   ColumnLayout {visible:panel.width>=720;Layout.fillWidth:true;spacing:5
    Repeater {model:panel.document ? panel.document.order : []
     delegate:Rectangle {
      id:row
      required property string modelData
      required property int index
      readonly property var details:Layers.findV2(panel.document,modelData) || Layers.layerV2(modelData)
      Layout.fillWidth:true;implicitHeight:58;radius:6
      color:!panel.sharedSelected && panel.currentId===modelData ? "#3d2832" : "#262127";border.color:!panel.sharedSelected && panel.currentId===modelData ? "#a15a70" : "#48343f"
      MouseArea {id:rowMouse;anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
       property real pressY:0
       onPressed:mouse=>{pressY=mapToItem(list,mouse.x,mouse.y).y;if(mouse.button===Qt.RightButton){panel.openLayerMenu(row.modelData,row)}else panel.select(row.modelData)}
       onReleased:mouse=>{if(mouse.button!==Qt.LeftButton)return;const delta=mapToItem(list,mouse.x,mouse.y).y-pressY;if(Math.abs(delta)>22)panel.reorder(row.modelData,row.index+Math.round(delta/63))}
      }
      RowLayout {anchors.fill:parent;anchors.margins:7;spacing:5
       Text {Layout.preferredWidth:14;Layout.fillHeight:true;text:"≡";color:"#b18899";verticalAlignment:Text.AlignVCenter
        MouseArea {anchors.fill:parent;cursorShape:Qt.SizeVerCursor;property real origin:0;onPressed:mouse=>{origin=mapToItem(list,mouse.x,mouse.y).y};onReleased:mouse=>{const delta=mapToItem(list,mouse.x,mouse.y).y-origin;panel.reorder(row.modelData,row.index+Math.round(delta/63))}}
       }
       StudioButton {Layout.fillWidth:true;Layout.minimumWidth:36;implicitWidth:80;objectName:"selectLayer_"+row.modelData;text:(row.index+1)+" · "+row.details.name+(row.modelData==="main" ? " ◇" : "");onClicked:panel.select(row.modelData);Accessible.name:"Seleccionar "+row.details.name
        ToolTip.visible:hovered;ToolTip.text:({bars:"Barras",waves:"Ondas",particles:"Partículas"})[row.details.type]+" · "+(row.details.geometry.inherited ? "compartida" : "propia")+" · arrastra el borde de la fila para ordenar"
        Keys.onUpPressed:event=>{if(event.modifiers & Qt.AltModifier){panel.reorder(row.modelData,row.index-1);event.accepted=true}else event.accepted=false}
        Keys.onDownPressed:event=>{if(event.modifiers & Qt.AltModifier){panel.reorder(row.modelData,row.index+1);event.accepted=true}else event.accepted=false}
       }
       StudioToolButton {objectName:"visibility_"+row.modelData;text:row.details.enabled ? "◉" : "○";Accessible.name:(row.details.enabled ? "Ocultar " : "Mostrar ")+row.details.name;ToolTip.visible:hovered;ToolTip.text:row.details.enabled ? "Visible" : "Oculta";onClicked:panel.controller.setLayerEnabled(row.modelData,!row.details.enabled)}
       StudioToolButton {id:rowMenuButton;objectName:"layerMenuButton_"+row.modelData;text:"⋯";Accessible.name:"Opciones de "+row.details.name;onClicked:panel.openLayerMenu(row.modelData,rowMenuButton)}
      }
     }
    }
   }
   Label {Layout.fillWidth:true;visible:panel.layerActionMessage!=="";text:panel.layerActionMessage;wrapMode:Text.WordWrap;color:"#e6a9bd";font.pixelSize:12}
   Label {visible:panel.width>=720;Layout.fillWidth:true;color:"#ad95a3";font.pixelSize:11;wrapMode:Text.WordWrap;text:"Orden: fondo → frente. Arrastra el borde de una fila o usa ⋯ / Alt+↑↓. ◇ Principal protegida."}
   StudioButton {visible:panel.document && panel.document.legacy && !!panel.document.legacy.particles;Layout.fillWidth:true;text:"Recuperar partículas anteriores";enabled:panel.document && panel.document.layers.length<4;onClicked:{panel.finish();const id=panel.controller.importLegacyParticles();if(id)panel.select(id)}}
  }
  ColumnLayout {Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop
   Label {Layout.fillWidth:true;visible:panel.controller.error!=="" || !!panel.controller.resolution.error;color:"#ecb0c2";wrapMode:Text.WordWrap;text:panel.controller.error || panel.controller.resolution.error}
   Loader {id:inspector;enabled:panel.document!==null;Layout.fillWidth:true;sourceComponent:panel.sharedSelected ? sharedInspector : layerInspector}
   ColumnLayout {Layout.fillWidth:true;visible:panel.resetPending
    Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e3a8ba";text:"Restablecer apariencia, transformaciones y animación del tipo actual. Se conservan geometría, recortes y ajustes de los otros tipos."}
    Flow {Layout.fillWidth:true;spacing:6;StudioButton {text:"Restablecer capa";onClicked:{panel.controller.resetLayer(panel.resetId);panel.resetPending=false}}StudioButton {text:"Cancelar";onClicked:panel.resetPending=false}}
   }
  }
 }
 Component {id:sharedInspector;ColumnLayout {Layout.fillWidth:true
  Label {Layout.fillWidth:true;text:"Figura compartida";font.pixelSize:18;font.bold:true;color:"#eadce4"}
  LayerGeometryPanel {id:sharedGeometry;Layout.fillWidth:true;controller:panel.controller;settings:panel.settings;shared:true;selectedVertex:panel.sharedPointSelection;showPoints:panel.sharedPointsVisible
   onPointSelected:index=>panel.sharedPointSelection=index
   onShowPointsChanged:panel.sharedPointsVisible=showPoints
   Connections {target:panel;function onSharedPointSelectionChanged(){if(sharedGeometry.selectedVertex!==panel.sharedPointSelection)sharedGeometry.selectedVertex=panel.sharedPointSelection}function onSharedPointsVisibleChanged(){if(sharedGeometry.showPoints!==panel.sharedPointsVisible)sharedGeometry.showPoints=panel.sharedPointsVisible}}
  }
 }}
 Component {id:layerInspector;StudioLayerInspector {Layout.fillWidth:true;controller:panel.controller;settings:panel.settings;layerData:panel.selectedLayer;onEditSharedRequested:panel.selectShared()}}
 readonly property StudioMenu actionsMenu:layerMenu
 readonly property QtObject menuHost:QtObject {
  readonly property StudioMenu actions:StudioMenu {
  id:layerMenu;objectName:"layerActionsMenu"
  width:Math.min(280,Math.max(180,panel.width-12))
  height:Math.min(implicitHeight,panel.hostWindow ? Math.max(100,panel.hostWindow.height-16) : implicitHeight)
  contentItem:ListView {implicitHeight:contentHeight;model:layerMenu.contentModel;currentIndex:layerMenu.currentIndex;interactive:contentHeight>height;clip:true;ScrollIndicator.vertical:ScrollIndicator {}}
  StudioMenuItem {text:"Capa: "+panel.menuName;enabled:false}
  StudioMenuItem {objectName:"deleteLayerAction";text:"Eliminar capa";enabled:panel.canDeleteMenuLayer;onTriggered:panel.deleteMenuLayer()}
  StudioMenuItem {
   objectName:"deleteLayerReason";visible:!panel.canDeleteMenuLayer;enabled:false
   height:visible ? implicitHeight : 0
   implicitHeight:Math.max(36,contentItem.implicitHeight+12)
   contentItem:Text {width:layerMenu.width-26;text:panel.deleteReason;color:"#c7a5b3";font.pixelSize:11;wrapMode:Text.WordWrap}
  }
  MenuSeparator {}
  StudioMenuItem {text:"Duplicar capa";enabled:panel.menuTargetCurrent && panel.document.layers.length<4;onTriggered:{panel.select(panel.menuId);panel.add(true)}}
  StudioMenuItem {text:"Hacia el fondo";enabled:panel.menuTargetCurrent && panel.document.order.indexOf(panel.menuId)>0;onTriggered:panel.reorder(panel.menuId,panel.document.order.indexOf(panel.menuId)-1)}
  StudioMenuItem {text:"Hacia el frente";enabled:panel.menuTargetCurrent && panel.document.order.indexOf(panel.menuId)<panel.document.order.length-1;onTriggered:panel.reorder(panel.menuId,panel.document.order.indexOf(panel.menuId)+1)}
  StudioMenuItem {text:"Restablecer apariencia…";enabled:panel.menuTargetCurrent;onTriggered:{panel.select(panel.menuId);panel.resetId=panel.menuId;panel.resetPending=true}}
  }
 }
}
