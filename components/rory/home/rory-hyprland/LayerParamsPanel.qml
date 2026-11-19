pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
GridLayout {
 id: panel
 required property var controller
 required property var layerData
 required property string kind
 required property var specs
 Layout.fillWidth: true
 columns: width<560 ? 1 : 2
 columnSpacing:12;rowSpacing:8
 Repeater {
  model: panel.specs
  delegate: VisualizerSlider {
   required property var modelData
   objectName: panel.kind+"_"+modelData.key
   Layout.fillWidth:true
   controller:panel.controller
   label:modelData.label
   explanation:modelData.explanation || ""
   from:modelData.from;to:modelData.to;decimals:modelData.decimals===undefined ? 1 : modelData.decimals
   suffix:modelData.suffix || ""
   value: Number.isFinite(panel.layerData.params[panel.kind][modelData.key]) ? panel.layerData.params[panel.kind][modelData.key] : modelData.from
   onValueEdited:v=>panel.controller.editParam(panel.layerData.id,panel.kind,modelData.key,modelData.decimals===0 ? Math.round(v) : v)
  }
 }
}
