pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:panel
 required property var controller
 required property var settings
 Label {Layout.fillWidth:true;text:"Audio global";color:"#eadce5";font.pixelSize:19;font.bold:true}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#c4aeb9";text:"Una fuente CAVA / PipeWire para todas las capas. La reacción y las animaciones de cada capa se editan en su inspector."}
 StudioToggle {objectName:"visualizerVisibility";text:"Visualizador visible en este fondo";checked:panel.settings.effectiveVisualizerEnabled;onToggled:panel.settings.setVisualizerVisibility(checked)}
 StudioToggle {objectName:"visualizerTestMode";text:"Prueba sin audio real";checked:panel.settings.visualizerTestMode;onToggled:panel.controller.setValue("visualizerTestMode",checked)}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:panel.settings.visualizerStatus || "Esperando datos de la fuente compartida";color:"#d2abbc";font.pixelSize:12}
 Repeater {model:[{key:"visualizerSensitivity",label:"Sensibilidad global",from:50,to:200},{key:"visualizerBass",label:"Respuesta de graves",from:0,to:100},{key:"visualizerAttack",label:"Ataque global",from:5,to:95},{key:"visualizerSmoothing",label:"Suavizado global de caídas",from:5,to:95}]
  delegate:VisualizerSlider {required property var modelData;Layout.fillWidth:true;controller:panel.controller;objectName:"global_"+modelData.key;label:modelData.label;explanation:"Afecta a la señal compartida; no cambia los ajustes guardados de las capas.";from:modelData.from;to:modelData.to;decimals:1;suffix:"%";value:panel.settings[modelData.key];onValueEdited:v=>panel.controller.setValue(modelData.key,v)}
 }
 StudioSection {title:"Barras en silencio"
  StudioToggle {objectName:"hideSilentBars";text:"Ocultar barras en silencio";checked:panel.settings.visualizerHideSilentBars;onToggled:panel.controller.setValue("visualizerHideSilentBars",checked)}
  ColumnLayout {
   Layout.fillWidth:true
   enabled:panel.settings.visualizerHideSilentBars
   VisualizerSlider {objectName:"silenceThreshold";Layout.fillWidth:true;controller:panel.controller;label:"Umbral de silencio";explanation:"Porcentaje del nivel máximo de la señal de CAVA.";from:.1;to:30;decimals:1;suffix:" %";value:panel.settings.visualizerSilenceThreshold;onValueEdited:v=>panel.controller.setValue("visualizerSilenceThreshold",v)}
   VisualizerSlider {objectName:"silenceHold";Layout.fillWidth:true;controller:panel.controller;label:"Tiempo de espera antes de ocultar";explanation:"";from:100;to:5000;step:50;suffix:" ms";value:panel.settings.visualizerSilenceHold;onValueEdited:v=>panel.controller.setValue("visualizerSilenceHold",v)}
   VisualizerSlider {objectName:"silenceFade";Layout.fillWidth:true;controller:panel.controller;label:"Duración del desvanecimiento";explanation:"";from:50;to:2000;step:50;suffix:" ms";value:panel.settings.visualizerSilenceFade;onValueEdited:v=>panel.controller.setValue("visualizerSilenceFade",v)}
  }
 }
 Label {Layout.fillWidth:true;text:"El número de barras se ajusta en Composición, encima de la lista de capas.";color:"#bea8b3";wrapMode:Text.WordWrap}

 StudioSection {title:"Compatibilidad de efectos anteriores";expanded:false
  StudioCombo {
   id:compatibilityEffect;objectName:"legacyEffectSelector";Layout.fillWidth:true
   model:panel.settings.visualizerEffects.map(effect=>effect.name+(effect.ready ? "" : " · no disponible"))
   currentIndex:panel.settings.visualizerEffects.findIndex(effect=>effect.id===panel.settings.visualizerEffect)
   delegate:ItemDelegate {id:effectOption;required property var modelData;required property int index;width:compatibilityEffect.width;height:36;enabled:panel.settings.visualizerEffects[index].ready;highlighted:compatibilityEffect.highlightedIndex===index;contentItem:Text {text:String(effectOption.modelData);color:effectOption.enabled ? "#e9dde5" : "#8c7b86";elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}}
   onActivated:index=>{const effect=panel.settings.visualizerEffects[index];if(effect.ready)panel.controller.setValue("visualizerEffect",effect.id);currentIndex=Qt.binding(()=>panel.settings.visualizerEffects.findIndex(item=>item.id===panel.settings.visualizerEffect))}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#b6a0ab";font.pixelSize:11;text:"Barras, partículas y ondas actuales se eligen por capa en Composición. Este catálogo conserva los identificadores anteriores; los efectos no disponibles no se activan."}
 }
}
