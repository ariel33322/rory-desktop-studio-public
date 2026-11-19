pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:panel
 required property var controller
 required property var layerData
 readonly property var modes:["none","pulse","rotate","breathe","sway"]
 StudioToggle {text:"Reproducir animación";enabled:panel.layerData.animation.mode!=="none";checked:panel.layerData.animation.enabled && panel.layerData.animation.mode!=="none";onToggled:panel.controller.editAnimation(panel.layerData.id,"enabled",checked)}
 StudioCombo {id:animationModeControl;objectName:"animationType";Layout.fillWidth:true;model:["Sin animación","Pulsación de escala","Rotación continua","Respiración","Oscilación suave"];currentIndex:panel.modes.indexOf(panel.layerData.animation.mode);onActivated:index=>{panel.forceActiveFocus();panel.controller.beginTransaction();panel.controller.editAnimation(panel.layerData.id,"mode",panel.modes[index]);if(index>0)panel.controller.editAnimation(panel.layerData.id,"enabled",true);panel.controller.endTransaction();animationModeControl.forceActiveFocus()}}
 StudioCombo {visible:panel.layerData.animation.mode!=="none";Layout.fillWidth:true;model:["Dirección positiva","Dirección negativa"];currentIndex:panel.layerData.animation.direction===-1 ? 1 : 0;onActivated:index=>panel.controller.editAnimation(panel.layerData.id,"direction",index===1 ? -1 : 1)}
 GridLayout {
  Layout.fillWidth:true;columns:width<560 ? 1 : 2;columnSpacing:12;rowSpacing:8
  Repeater {
   model:[{key:"speed",label:"Velocidad",from:0,to:5,decimals:2},{key:"intensity",label:"Intensidad",from:0,to:100},{key:"sensitivity",label:"Sensibilidad",from:0,to:250},{key:"smoothing",label:"Suavizado",from:0,to:95}]
   delegate:VisualizerSlider {
    required property var modelData
    objectName:"animation_"+modelData.key;Layout.fillWidth:true;controller:panel.controller
    label:modelData.label;explanation:"";from:modelData.from;to:modelData.to;decimals:modelData.decimals===undefined ? 1 : modelData.decimals
    value:panel.layerData.animation[modelData.key]
    onValueEdited:v=>panel.controller.editAnimation(panel.layerData.id,modelData.key,v)
   }
  }
 }
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Transformación temporal: no cambia la figura ni los valores guardados.";color:"#aa969d";font.pixelSize:11}
}
