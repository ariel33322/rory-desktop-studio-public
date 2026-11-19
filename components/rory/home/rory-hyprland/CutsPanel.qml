pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "PathCuts.js" as Cuts
import "LayerGeometry.js" as Geometry
import "AudioLayers.js" as Layers
ColumnLayout {
 id:panel
 required property var controller
 required property var settings
 required property var layerData
 property real selectionStart:0
 property real selectionLength:.25
 property int activeInterval:-1
 property real zoom:1
 property bool conversionPending:false
 readonly property var pathSettings:Geometry.resolve(settings,layerData.geometry)
 property bool degrees:pathSettings.visualizerGeometry==="circle" || pathSettings.visualizerGeometry==="ellipse"
 readonly property real units:degrees ? 360 : 100
 readonly property string suffix:degrees ? "°" : "%"
 readonly property string contextId:layerData.id
 onContextIdChanged:{activeInterval=-1;conversionPending=false;if(visible)forceActiveFocus();controller.endTransaction()}
 onVisibleChanged:if(!visible)controller.endTransaction()
 readonly property var cuts:layerData.cuts || Cuts.defaults()
 readonly property var selectedInterval:cuts.intervals[activeInterval]
 function deleteInterval() {
  forceActiveFocus()
  controller.finishPendingInputs()
  controller.endTransaction()
  if(!selectedInterval)return
  const next=Layers.copy(cuts)
  next.intervals.splice(activeInterval,1)
  activeInterval=-1
  controller.setCuts(layerData.id,next)
 }
 function selectInterval(index){forceActiveFocus();controller.endTransaction();activeInterval=index;const span=cuts.intervals[index];if(span){selectionStart=span.start;selectionLength=span.length}}
 function setRange(start,length){
  selectionStart=Cuts.wrap(start);selectionLength=Math.max(0,Math.min(1,length))
  if(activeInterval>=0 && activeInterval<cuts.intervals.length){const next=Layers.copy(cuts);next.intervals[activeInterval].start=selectionStart;next.intervals[activeInterval].length=selectionLength;controller.setCuts(layerData.id,next)}
 }
 function apply(shown){forceActiveFocus();controller.cutRange(layerData.id,selectionStart,selectionLength,shown);activeInterval=cuts.intervals.length-1}
 function selectBar(index,extend){forceActiveFocus();activeInterval=-1;if(extend){const first=Math.round(selectionStart*settings.visualizerBarCount);setRange(Math.min(first,index)/settings.visualizerBarCount,(Math.abs(first-index)+1)/settings.visualizerBarCount)}else setRange(index/settings.visualizerBarCount,1/settings.visualizerBarCount)}
 function toggleBar(index){controller.cutRange(layerData.id,index/settings.visualizerBarCount,1/settings.visualizerBarCount,!Cuts.visibleAt(cuts,index/settings.visualizerBarCount));activeInterval=-1}
 onCutsChanged:{
  if(activeInterval>=cuts.intervals.length)activeInterval=-1
  if(activeInterval>=0){selectionStart=cuts.intervals[activeInterval].start;selectionLength=cuts.intervals[activeInterval].length}
 }
 Label {Layout.fillWidth:true;text:"Tramos y recortes · "+panel.layerData.name;color:"#c78598";font.pixelSize:16;wrapMode:Text.WordWrap}
 Label {Layout.fillWidth:true;text:"Selecciona una barra; Shift amplía el rango. Clic derecho oculta/restaura. Arrastra I/F para ajustar extremos. Botón central desplaza el zoom. Los intervalos más recientes prevalecen.";color:"#b7a6b0";wrapMode:Text.WordWrap;font.pixelSize:11}
 StudioToggle {text:"Unidades angulares (0° = inicio del recorrido)";visible:panel.pathSettings.visualizerGeometry==="circle" || panel.pathSettings.visualizerGeometry==="ellipse";checked:panel.degrees;onToggled:panel.degrees=checked}
 CutPreview {id:preview;Layout.fillWidth:true;settings:panel.pathSettings;layerData:panel.layerData;controller:panel.controller;activeInterval:panel.activeInterval;selectionStart:panel.selectionStart;selectionLength:panel.selectionLength;zoom:panel.zoom
  onIntervalChosen:index=>panel.selectInterval(index)
  onRangeEdited:(start,length)=>panel.setRange(start,length)
  onBarSelected:(index,extend)=>panel.selectBar(index,extend)
  onBarToggled:index=>panel.toggleBar(index)
 }
 Label {Layout.fillWidth:true;color:"#b7a6b0";font.pixelSize:11;wrapMode:Text.WordWrap;text:"Carmesí: visible · gris: oculto · blanco: selección. La vista es esquemática; el audio sigue en el escritorio."}
 Label {Layout.fillWidth:true;color:"#dec2cc";wrapMode:Text.WordWrap;text:"Barras "+(Math.floor(panel.selectionStart*panel.settings.visualizerBarCount)+1)+" → "+(Math.floor(Cuts.wrap(panel.selectionStart+panel.selectionLength)*panel.settings.visualizerBarCount)+1)+" · "+panel.settings.visualizerBarCount+" muestras. Los extremos ajustan el intervalo seleccionado; una selección nueva requiere Ocultar/Restaurar."}
 GridLayout {Layout.fillWidth:true;columns:width<560 ? 1 : 2;columnSpacing:12
  VisualizerSlider {objectName:"cutStart";Layout.fillWidth:true;controller:panel.controller;label:"Inicio";explanation:"";from:0;to:panel.units;decimals:2;value:panel.selectionStart*panel.units;suffix:panel.suffix;onValueEdited:v=>panel.setRange(v/panel.units,panel.selectionLength)}
  VisualizerSlider {objectName:"cutEnd";Layout.fillWidth:true;controller:panel.controller;label:"Fin";explanation:"El tramo puede cruzar el origen.";from:0;to:panel.units;decimals:2;value:(panel.selectionStart+panel.selectionLength<=1+1e-9 ? Math.min(1,panel.selectionStart+panel.selectionLength) : Cuts.wrap(panel.selectionStart+panel.selectionLength))*panel.units;suffix:panel.suffix;onValueEdited:v=>panel.setRange(panel.selectionStart,v/panel.units-panel.selectionStart>=1-1e-9 ? 1 : Cuts.wrap(v/panel.units-panel.selectionStart))}
  VisualizerSlider {objectName:"cutLength";Layout.fillWidth:true;controller:panel.controller;label:"Longitud del tramo";explanation:"";from:0;to:panel.units;decimals:2;value:panel.selectionLength*panel.units;suffix:panel.suffix;onValueEdited:v=>panel.setRange(panel.selectionStart,v/panel.units)}
  VisualizerSlider {Layout.fillWidth:true;controller:panel.controller;label:"Zoom de edición";explanation:"Sólo afecta esta vista.";from:1;to:6;decimals:2;value:panel.zoom;suffix:"×";onValueEdited:v=>panel.zoom=v}
 }
 RowLayout {Layout.fillWidth:true
  StudioCombo {objectName:"cutIntervalSelector";Layout.fillWidth:true;model:["Nueva selección · no modifica la figura"].concat(panel.cuts.intervals.map((span,i)=>(i+1)+" · "+(span.visible ? "visible " : "oculto ")+(span.start*panel.units).toFixed(1)+panel.suffix+" · "+(span.length*panel.units).toFixed(1)+panel.suffix));currentIndex:panel.activeInterval+1;onActivated:index=>{if(index===0){panel.forceActiveFocus();panel.activeInterval=-1}else panel.selectInterval(index-1)}}
  StudioToolButton {text:"⋯";Accessible.name:"Operaciones de tramos";onClicked:cutMenu.popup()}
 }
 Label {objectName:"cutEditState";Layout.fillWidth:true;text:panel.activeInterval<0 ? "Seleccionando · pulsa Ocultar o Restaurar para aplicar" : "Editando intervalo "+(panel.activeInterval+1)+" · extremos y números se aplican al instante";color:"#d9b1c2";font.pixelSize:12;wrapMode:Text.WordWrap}
 Flow {Layout.fillWidth:true;spacing:6
  StudioButton {objectName:"hideRange";text:"Ocultar tramo";onClicked:panel.apply(false)}
  StudioButton {objectName:"restoreRange";text:"Restaurar tramo";onClicked:panel.apply(true)}
  StudioButton {objectName:"deleteHiddenRange";text:"Eliminar tramo";visible:panel.selectedInterval?.visible===false;onClicked:panel.deleteInterval()}
  StudioButton {text:"Ajustar vista";onClicked:{panel.zoom=1;preview.panX=0;preview.panY=0}}
 }
 ColumnLayout {Layout.fillWidth:true;visible:panel.conversionPending
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e4b0c0";text:"Convertir la máscara actual en intervalos visibles conserva la apariencia, pero reemplaza la lista de operaciones. Puedes deshacer."}
  Flow {Layout.fillWidth:true;spacing:6;StudioButton {objectName:"convertVisibleSpans";text:"Convertir a tramos visibles";onClicked:{panel.activeInterval=-1;panel.controller.setCuts(panel.layerData.id,Cuts.visibleSpans(panel.cuts));if(panel.cuts.intervals.length)panel.selectInterval(0);panel.conversionPending=false}}StudioButton {text:"Cancelar";onClicked:panel.conversionPending=false}}
 }
 StudioMenu {id:cutMenu
  StudioMenuItem {text:"Nueva selección";onTriggered:{panel.forceActiveFocus();panel.activeInterval=-1}}
  StudioMenuItem {text:"Invertir rango seleccionado";onTriggered:{panel.activeInterval=-1;panel.setRange(panel.selectionStart+panel.selectionLength,1-panel.selectionLength)}}
  StudioMenuItem {text:"Mostrar sólo la selección";onTriggered:{panel.controller.setCuts(panel.layerData.id,{baseVisible:false,intervals:[{start:panel.selectionStart,length:panel.selectionLength,visible:true}]});panel.activeInterval=0}}
  MenuSeparator {}
  StudioMenuItem {text:"Seleccionar ½ del recorrido";onTriggered:{panel.activeInterval=-1;panel.setRange(0,.5)}}
  StudioMenuItem {text:"Seleccionar ¼ del recorrido";onTriggered:{panel.activeInterval=-1;panel.setRange(0,.25)}}
  StudioMenuItem {text:"Seleccionar ⅛ del recorrido";onTriggered:{panel.activeInterval=-1;panel.setRange(0,.125)}}

  MenuSeparator {}
  StudioMenuItem {text:"Convertir máscara a tramos visibles…";onTriggered:panel.conversionPending=true}
  StudioMenuItem {text:"Eliminar intervalo seleccionado";enabled:!!panel.selectedInterval;onTriggered:panel.deleteInterval()}
  StudioMenuItem {text:"Restaurar todos los recortes";onTriggered:{panel.activeInterval=-1;panel.controller.setCuts(panel.layerData.id,Cuts.defaults())}}
 }
}
