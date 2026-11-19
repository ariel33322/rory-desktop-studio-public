pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:panel
 required property var controller
 required property var settings
 required property var layerData
 signal editSharedRequested()
 objectName:"layerInspector"
 spacing:12
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#eedee7";font.pixelSize:18;font.bold:true;text:panel.layerData.name+(panel.layerData.enabled ? "" : " · oculta")}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bca0ae";font.pixelSize:11;text:"Editando sólo esta capa · "+(panel.layerData.geometry.inherited ? "figura compartida" : "geometría propia")}
 StylePanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData}
 StudioSection {objectName:"layerGeometrySection";title:"Geometría y dimensiones";expanded:false
  LayerGeometryPanel {Layout.fillWidth:true;controller:panel.controller;settings:panel.settings;layerData:panel.layerData;onEditSharedRequested:panel.editSharedRequested()}
 }
 StudioSection {objectName:"layerPositionSection";title:"Posición relativa";expanded:false
  GridLayout {Layout.fillWidth:true;columns:width<560 ? 1 : 2;columnSpacing:12;rowSpacing:8
   Repeater {model:[{key:"x",label:"Posición X relativa",from:-1920,to:1920,suffix:"px"},{key:"y",label:"Posición Y relativa",from:-1080,to:1080,suffix:"px"},{key:"scale",label:"Escala de capa",from:.1,to:4,decimals:2,suffix:"×"},{key:"rotation",label:"Giro relativo",from:-180,to:180,suffix:"°"},{key:"normalOffset",label:"Desplazamiento normal",from:-300,to:300,suffix:"px"}]
    delegate:VisualizerSlider {required property var modelData;objectName:"common_"+modelData.key;Layout.fillWidth:true;controller:panel.controller;label:modelData.label;explanation:"";from:modelData.from;to:modelData.to;decimals:modelData.decimals===undefined ? 1 : modelData.decimals;suffix:modelData.suffix;value:panel.layerData.common[modelData.key];onValueEdited:v=>panel.controller.editCommon(panel.layerData.id,modelData.key,v)}
   }
  }
 }
 StudioSection {title:"Apariencia";expanded:true
  StudioColorEditor {Layout.fillWidth:true;controller:panel.controller;contextKey:panel.layerData.id;value:panel.layerData.type==="particles" && panel.layerData.params.particles.useVisualizerColor ? panel.controller.document.layers.find(layer=>layer.id==="main").common.color : panel.layerData.common.color;enabled:panel.layerData.type!=="particles" || !panel.layerData.params.particles.useVisualizerColor;onColorEdited:color=>panel.controller.editCommon(panel.layerData.id,"color",color)}
  Label {Layout.fillWidth:true;visible:panel.layerData.type==="particles" && panel.layerData.params.particles.useVisualizerColor;wrapMode:Text.WordWrap;color:"#bca5b1";font.pixelSize:11;text:"Color heredado de la principal. El color propio se conserva para cuando desactives la herencia."}
  VisualizerSlider {objectName:"common_opacity";Layout.fillWidth:true;controller:panel.controller;label:"Opacidad";explanation:"Sólo esta capa.";from:0;to:100;decimals:1;suffix:"%";value:panel.layerData.common.opacity;onValueEdited:v=>panel.controller.editCommon(panel.layerData.id,"opacity",v)}
  Loader {Layout.fillWidth:true;sourceComponent:panel.layerData.type==="bars" ? barsAppearance : panel.layerData.type==="waves" ? wavesAppearance : particlesAppearance}
 }
 StudioSection {objectName:"layerAudioSection";title:"Audio de esta capa";expanded:false
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#bca8b2";font.pixelSize:11;text:"La fuente CAVA es compartida. Estos controles sólo afectan a esta representación."}
  LayerParamsPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData;kind:panel.layerData.type
   specs:[{key:"intensity",label:"Reacción",from:0,to:100,suffix:"%"},{key:"sensitivity",label:"Sensibilidad de capa",from:0,to:250,suffix:"%"}].concat(panel.layerData.type==="particles" ? [] : [{key:"temporal",label:"Suavizado temporal de capa",from:0,to:95,suffix:"%"}])}
 }
 StudioSection {objectName:"layerGlowSection";title:"Glow";expanded:false;visible:panel.layerData.type!=="particles"
  StudioToggle {text:"Halo de esta capa";checked:!!panel.layerData.params[panel.layerData.type].glowEnabled;onToggled:panel.controller.editParam(panel.layerData.id,panel.layerData.type,"glowEnabled",checked)}
  Label {Layout.fillWidth:true;color:"#bba4b0";font.pixelSize:11;wrapMode:Text.WordWrap;text:panel.layerData.params[panel.layerData.type].glowEnabled ? "El suavizado sólo afecta al brillo." : "Halo apagado. Puedes preparar sus ajustes sin activarlo."}
  LayerParamsPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData;kind:panel.layerData.type;specs:panel.layerData.type==="particles" ? [] : [{key:"glow",label:"Extensión",from:0,to:16,decimals:2,suffix:"px"},{key:"glowIntensity",label:"Brillo",from:0,to:100,suffix:"%"},{key:"glowSensitivity",label:"Sensibilidad del halo",from:0,to:200,suffix:"%"},{key:"glowSmoothing",label:"Suavizado del halo",from:0,to:95,suffix:"%"}]}
 }
 StudioSection {objectName:"layerAnimationSection";title:"Animación de capa";expanded:false;AnimationPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData}}
 StudioSection {objectName:"layerCutsSection";title:"Tramos y recortes";expanded:false;CutsPanel {Layout.fillWidth:true;controller:panel.controller;settings:panel.settings;layerData:panel.layerData}}
 Component {id:barsAppearance;ColumnLayout {Layout.fillWidth:true
  StudioCombo {Layout.fillWidth:true;model:["Barras hacia fuera","Barras hacia dentro"];currentIndex:panel.layerData.params.bars.direction===-1 ? 1 : 0;onActivated:index=>panel.controller.editParam(panel.layerData.id,"bars","direction",index===1 ? -1 : 1)}
  LayerParamsPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData;kind:"bars";specs:[{key:"length",label:"Altura máxima",from:8,to:140,suffix:"px"},{key:"thickness",label:"Grosor",from:1,to:12,decimals:2,suffix:"px"},{key:"gap",label:"Separación",from:0,to:9,decimals:2,suffix:"px"}]}
 }}
 Component {id:wavesAppearance;WavesPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData}}
 Component {id:particlesAppearance;ParticlesPanel {Layout.fillWidth:true;controller:panel.controller;layerData:panel.layerData}}
}
