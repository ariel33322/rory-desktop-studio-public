pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Representation.js" as Styles
ColumnLayout {
 id:panel
 required property var controller
 required property var layerData
 readonly property var catalog:Styles.catalog().map(entry=>({id:entry.id,type:entry.type,label:(entry.type==="bars" ? "Barras · " : "Ondas · ")+entry.label})).concat([{id:"sparks",type:"particles",label:"Partículas · Chispas"},{id:"dust",type:"particles",label:"Partículas · Polvo luminoso"},{id:"orbit",type:"particles",label:"Partículas · Órbita"}])
 readonly property string currentStyle:layerData.type==="particles" ? layerData.params.particles.mode : layerData.styles ? layerData.styles[layerData.type] || "" : ""
 StudioSection {title:"Representación";expanded:true
  Label {Layout.fillWidth:true;text:"Motor: "+({bars:"Barras",waves:"Ondas",particles:"Partículas"})[panel.layerData.type]+" · los estilos conservan sus ajustes.";color:"#b7a6b0";wrapMode:Text.WordWrap;font.pixelSize:11}
  StudioCombo {
   id:selector;objectName:"representationStyle";Layout.fillWidth:true
   model:panel.catalog.map(entry=>entry.label)
   currentIndex:panel.catalog.findIndex(entry=>entry.id===panel.currentStyle)
   onActivated:index=>{panel.forceActiveFocus();panel.controller.endTransaction();const entry=panel.catalog[index];panel.controller.beginTransaction();if(entry.type==="particles"){panel.controller.setLayerType(panel.layerData.id,"particles");panel.controller.editParam(panel.layerData.id,"particles","mode",entry.id)}else panel.controller.setLayerStyle(panel.layerData.id,entry.id);panel.controller.endTransaction();selector.forceActiveFocus()}
  }
  LayerParamsPanel {controller:panel.controller;layerData:panel.layerData;kind:panel.layerData.type
   specs:panel.layerData.type==="particles" ? [] : [{key:"density",label:"Densidad",from:5,to:100,suffix:"%"}].concat(
    panel.currentStyle==="rounded" ? [{key:"rounding",label:"Redondeo",from:0,to:100,suffix:"%"}] :
    panel.currentStyle==="segmented" ? [{key:"segmentSize",label:"Largo de segmento",from:1,to:24,suffix:"px"},{key:"segmentGap",label:"Hueco entre segmentos",from:1,to:16,suffix:"px"}] :
    panel.currentStyle==="peaks" ? [{key:"peakDecay",label:"Caída de picos",from:1,to:200,suffix:"%/s"}] :
    panel.currentStyle==="fluid" ? [{key:"fluidness",label:"Fluidez",from:0,to:1,decimals:2}] : [])
  }
 }
}
