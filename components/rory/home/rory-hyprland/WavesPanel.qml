pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id: panel
 required property var controller
 required property var layerData
 readonly property var modes:["continuous","pulse","spectral"]

 StudioCombo {Layout.fillWidth:true;model:["Hacia fuera","Hacia dentro"];currentIndex:panel.layerData.params.waves.direction===-1 ? 1 : 0;onActivated:index=>panel.controller.editParam(panel.layerData.id,"waves","direction",index===1 ? -1 : 1)}
 LayerParamsPanel {controller:panel.controller;layerData:panel.layerData;kind:"waves";specs:panel.layerData.params.waves.mode==="spectral" || panel.layerData.styles.waves==="fluid" ? [{key:"spatial",label:"Suavizado espacial",from:0,to:4,decimals:0}] : []}
 LayerParamsPanel {controller:panel.controller;layerData:panel.layerData;kind:"waves";specs:panel.layerData.params.waves.mode==="spectral" ? [] : [{key:"speed",label:"Velocidad",from:0,to:5,decimals:2}]}
 LayerParamsPanel {
  controller:panel.controller;layerData:panel.layerData;kind:"waves"
  specs:[{key:"amplitude",label:"Amplitud",from:0,to:120,suffix:"px"},
   {key:"thickness",label:"Grosor",from:0.5,to:12,suffix:"px"}

]
 }
}
