pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id: panel
 required property var controller
 required property var layerData
 readonly property var modes:["sparks","dust","orbit"]
 LayerParamsPanel {
  controller:panel.controller;layerData:panel.layerData;kind:"particles"
  specs:[{key:"maximum",label:"Máximo",from:8,to:192,decimals:0},
   {key:"size",label:"Tamaño",from:0.5,to:8,decimals:2,suffix:"px"},
   {key:"speed",label:"Velocidad",from:0,to:240,suffix:"px/s"},
   {key:"life",label:"Vida útil",from:0.2,to:6,decimals:2,suffix:"s"},
   {key:"dispersion",label:"Dispersión",from:0,to:180,suffix:"px"}]
 }
 StudioToggle {
  text:"Usar el color de la principal"
  checked:panel.layerData.params.particles.useVisualizerColor
  onToggled:panel.controller.editParam(panel.layerData.id,"particles","useVisualizerColor",checked)
 }
}
