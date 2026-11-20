pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "LayerGeometry.js" as Geometry
import "IndependentCurve.js" as Curve
ColumnLayout {
 id:panel
 objectName:"geometryEditor"
 required property var controller
 required property var settings
 property var layerData:null
 property bool shared:false
 property bool showPoints:false
 property int selectedVertex:0
 signal editSharedRequested()
 signal pointSelected(int index)
 onSelectedVertexChanged:{if(wavePanel.selectedPoint!==selectedVertex)wavePanel.selectedPoint=selectedVertex;pointSelected(selectedVertex)}
 readonly property string contextId:shared ? "shared" : layerData ? layerData.id : ""
 readonly property var geometry:shared ? ({inherited:false,custom:null}) : layerData ? layerData.geometry || Geometry.defaults() : Geometry.defaults()
 readonly property var localSettings:shared ? settings : geometry.custom || Geometry.capture(settings)
 readonly property var shapes:["circle","ellipse","square","triangle","star","wave"]
 readonly property int vertexCount:Curve.controlCount(localSettings.visualizerGeometry,localSettings.visualizerShapeData)
 readonly property var vertices:Curve.readVertices(localSettings.visualizerShapeData,localSettings.visualizerGeometry,localSettings.visualizerIndependentVertices)
 function edit(key,value){if(shared)controller.setValue(key,value);else if(layerData)controller.editGeometry(layerData.id,key,value)}
 function editVertex(axis,value){if(shared){const p=vertices.slice();p[selectedVertex*2+axis]=value;edit("visualizerShapeData",Curve.writeVertices(settings.visualizerShapeData,settings.visualizerGeometry,p))}else controller.editLayerVertex(layerData.id,selectedVertex,axis,value)}
 onContextIdChanged:{selectedVertex=0;showPoints=false;controller.endTransaction()}
 onVertexCountChanged:if(selectedVertex>=vertexCount)selectedVertex=0
 RowLayout {Layout.fillWidth:true;visible:!panel.shared
  StudioCombo {Layout.fillWidth:true;objectName:"geometrySource";model:["Figura compartida","Geometría propia"];currentIndex:panel.geometry.inherited ? 0 : 1;onActivated:index=>{panel.forceActiveFocus();panel.controller.editGeometry(panel.layerData.id,"inherited",index===0)}}
  StudioToolButton {text:"⋯";Accessible.name:"Opciones de geometría";onClicked:geometryMenu.popup()}
 }
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#b6a3ad";font.pixelSize:11;text:panel.shared ? "Referencia de las capas heredadas. Ancho, alto y radios siguen siendo independientes." : panel.geometry.inherited ? "Esta capa sigue la figura compartida; editarla no cambia su configuración propia guardada." : "Sólo esta capa. Sus transformaciones relativas se ajustan en Posición."}
 StudioButton {visible:!panel.shared && panel.geometry.inherited;Layout.fillWidth:true;text:"Editar figura compartida";onClicked:panel.editSharedRequested()}
 readonly property bool linearMode: panel.shared && settings.visualizerEffect === "linear"
 RowLayout {
  Layout.fillWidth: true
  visible: panel.shared
  Label {text:"Trazado";color:"#ded5da"}
  StudioCombo {
   Layout.fillWidth:true
   model:["Figuras y contornos","Barras lineales"]
   currentIndex:panel.linearMode ? 1 : 0
   onActivated:index=>panel.controller.setValue("visualizerEffect",index===1 ? "linear" : "radial")
  }
 }
 ColumnLayout {
  Layout.fillWidth:true
  visible:panel.linearMode
  readonly property var config:panel.settings.visualizerLinear
  id:linePanel
  Label {text:"Colocación";color:"#ded5da"}
  StudioCombo {
   Layout.fillWidth:true
   readonly property var edges:["free","top","bottom","left","right"]
   model:["Libre","Borde superior","Borde inferior","Borde izquierdo","Borde derecho"]
   currentIndex:edges.indexOf(linePanel.config.edge)
   onActivated:index=>panel.controller.editLinear({edge:edges[index]})
  }
  StudioCombo {
   Layout.fillWidth:true
   visible:linePanel.config.edge==="free"
   model:["Horizontal","Vertical"]
   currentIndex:linePanel.config.direction==="horizontal" ? 0 : 1
   onActivated:index=>panel.controller.editLinear({direction:index===0 ? "horizontal" : "vertical"})
  }
  Repeater {
   model:[{key:"x",label:"Posición X",min:0,max:100},
       {key:"y",label:"Posición Y",min:0,max:100},{key:"inset",label:"Distancia al borde",min:0,max:4096},
       {key:"length",label:"Longitud de la línea",min:24,max:4096},{key:"height",label:"Altura máxima de las barras",min:1,max:2160},
       {key:"thickness",label:"Grosor de las barras",min:1,max:100},{key:"gap",label:"Separación mínima",min:0,max:100},
       {key:"count",label:"Cantidad de barras",min:24,max:384}]
   delegate:VisualizerSlider {
    required property var modelData
    Layout.fillWidth:true
    visible:modelData.key==="x" ? !["left","right"].includes(linePanel.config.edge)
        : modelData.key==="y" ? !["top","bottom"].includes(linePanel.config.edge)
        : modelData.key==="inset" ? linePanel.config.edge!=="free" : true
    controller:panel.controller
    label:modelData.label
    explanation:""
    from:modelData.min
    to:modelData.max
    suffix:modelData.key==="x" || modelData.key==="y" ? " %" : modelData.key==="count" ? "" : " px"
    decimals:0
    step:1
    value:linePanel.config[modelData.key]
    onValueEdited:v=>panel.controller.editLinear({[modelData.key]:v})
   }
  }
  StudioToggle {text:"Ajustar con puntero";checked:panel.settings.visualizerPointerEditMode;onToggled:panel.settings.visualizerPointerEditMode=checked}
 }
 ColumnLayout {Layout.fillWidth:true;visible:!panel.linearMode && (panel.shared || !panel.geometry.inherited)
  StudioCombo {Layout.fillWidth:true;objectName:"localGeometry";model:["Círculo","Elipse","Cuadrado","Triángulo","Estrella","Onda libre"];currentIndex:panel.shapes.indexOf(panel.localSettings.visualizerGeometry);onActivated:index=>{panel.forceActiveFocus();panel.edit("visualizerGeometry",panel.shapes[index])}}
  GridLayout {Layout.fillWidth:true;columns:width<560 ? 1 : 2;columnSpacing:12;rowSpacing:8
   Repeater {model:[{key:"visualizerWidth",label:"Ancho",from:120,to:1400},{key:"visualizerHeight",label:"Alto",from:120,to:1400},{key:"visualizerRadiusX",label:"Radio X",from:60,to:700},{key:"visualizerRadiusY",label:"Radio Y",from:60,to:700},{key:"visualizerOrientation",label:"Orientación de figura",from:-180,to:180},{key:"visualizerOffset",label:"Separación del contorno",from:-300,to:300},{key:"visualizerScale",label:"Escala de figura",from:.1,to:4}]
    delegate:VisualizerSlider {required property var modelData;objectName:"local_"+modelData.key;Layout.fillWidth:true;controller:panel.controller;label:modelData.label;explanation:"";from:modelData.from;to:modelData.to;decimals:modelData.key==="visualizerScale" ? 2 : 1;value:panel.localSettings[modelData.key];suffix:modelData.key==="visualizerOrientation" ? "°" : modelData.key==="visualizerScale" ? "×" : "px";onValueEdited:v=>panel.edit(modelData.key,v)}
   }
  }
  ColumnLayout {Layout.fillWidth:true;visible:panel.shared
   Repeater {model:["visualizerCenterX","visualizerCenterY"]
    delegate:VisualizerSlider {required property string modelData;required property int index;Layout.fillWidth:true;controller:panel.controller;label:index===0 ? "Centro X" : "Centro Y";explanation:"Coordenadas de la imagen base 1920 × 1080.";from:0;to:index===0 ? 1920 : 1080;decimals:1;value:panel.settings[modelData];suffix:"px";onValueEdited:v=>panel.edit(modelData,v)}
   }
   StudioToggle {objectName:"visualizerPointerToggle";text:"Ajustar con puntero";checked:panel.settings.visualizerPointerEditMode;onToggled:panel.settings.visualizerPointerEditMode=checked}
   Label {visible:panel.settings.visualizerPointerEditMode;Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Arrastra para mover · Mayús + arrastre para girar. Usa la esquina ↘ para ajustar ancho y alto. Los puntos editan la figura compartida.";color:"#b7a1ac";font.pixelSize:11}
  }
  StudioCombo {visible:panel.shared || panel.localSettings.visualizerGeometry!=="wave" || !Curve.hasAdvancedWave(panel.localSettings.visualizerShapeData);Layout.fillWidth:true;objectName:"vertexMode";model:["Vértices vinculados","Vértices independientes"];currentIndex:panel.localSettings.visualizerShapeMode==="independent" ? 1 : 0;onActivated:index=>panel.edit("visualizerShapeMode",index===1 ? "independent" : "linked")}
  StudioButton {Layout.fillWidth:true;objectName:"editPoints";text:panel.showPoints ? "Cerrar herramienta Puntos" : "Editar puntos y curvas";checkable:true;checked:panel.showPoints;onClicked:{panel.forceActiveFocus();panel.showPoints=!panel.showPoints}}
  FreeWavePanel {id:wavePanel;framed:false;Layout.fillWidth:true;visible:panel.showPoints && panel.localSettings.visualizerGeometry==="wave";controller:panel.controller;shapeSettings:panel.localSettings;onSelectedPointChanged:if(panel.selectedVertex!==selectedPoint)panel.selectedVertex=selectedPoint;layerId:panel.shared ? "" : panel.layerData ? panel.layerData.id : ""}
  ColumnLayout {Layout.fillWidth:true;visible:panel.showPoints && panel.localSettings.visualizerGeometry!=="wave"
   StudioCombo {Layout.fillWidth:true;model:Array.from({length:panel.vertexCount},(_,i)=>"Punto "+(i+1));currentIndex:panel.selectedVertex;onActivated:index=>{panel.forceActiveFocus();panel.selectedVertex=index}}
   Repeater {model:["X","Y"]
    delegate:VisualizerSlider {required property int index;required property string modelData;Layout.fillWidth:true;controller:panel.controller;enabled:panel.localSettings.visualizerShapeMode==="independent";label:"Punto "+(panel.selectedVertex+1)+" · "+modelData;explanation:"Coordenada relativa a los radios; activa vértices independientes para editar.";from:-3;to:3;decimals:3;value:panel.vertices[panel.selectedVertex*2+index] || 0;onValueEdited:v=>panel.editVertex(index,v)}
   }
  }
 }
 StudioMenu {id:geometryMenu;StudioMenuItem {text:"Copiar de nuevo la figura compartida";enabled:!panel.shared && !panel.geometry.inherited;onTriggered:panel.controller.copyLayerGeometry(panel.layerData.id)}}
}
