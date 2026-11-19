pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "FreeWave.js" as Wave
import "IndependentCurve.js" as Curve
ColumnLayout {
 id:panel
 required property var controller
 required property var shapeSettings
 property string layerId:""
 property bool framed:true
 property int selectedPoint:0
 property real zoom:1
 property real viewCenterX:0
 property real viewCenterY:0
 objectName:"freeWavePanel"
 readonly property var stored:Curve.parseObject(shapeSettings.visualizerShapeData).wave
 readonly property bool advanced:Wave.valid(stored)
 readonly property var path:advanced ? stored : Wave.create(Curve.readVertices(shapeSettings.visualizerShapeData,"wave",""))
 readonly property int pointCount:path.points.length/2
 onPointCountChanged: selectedPoint=Math.max(0,Math.min(selectedPoint,pointCount-1))
 function fitView(){
  const xs=[],ys=[];for(let i=0;i<pointCount;i++){xs.push(path.points[i*2]);ys.push(path.points[i*2+1]);if(path.mode==="bezier")for(let h=0;h<2;h++){xs.push(path.points[i*2]+path.handles[i*4+h*2]*path.rounding);ys.push(path.points[i*2+1]+path.handles[i*4+h*2+1]*path.rounding)}}
  const minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);viewCenterX=(minX+maxX)/2;viewCenterY=(minY+maxY)/2
  zoom=Math.max(.25,Math.min(6,Math.min((preview.width-36)/Math.max(.1,maxX-minX),(preview.height-36)/Math.max(.1,maxY-minY))/(Math.max(1,Math.min(preview.width,preview.height))/3)))
 }
 function cancelGesture(){mouseArea.dragPoint=-1;mouseArea.dragHandle=-1;controller.endTransaction()}
 onLayerIdChanged:{selectedPoint=0;cancelGesture();viewCenterX=0;viewCenterY=0;zoom=1}
 function commit(next){controller.editFreeWave(layerId,next)}
 function change(key,value){const next=Wave.copy(path);next[key]=value;commit(next)}
 function insertPoint(edge,t){const next=Wave.copy(path);const index=Wave.insert(next,edge,t);if(index>=0){commit(next);selectedPoint=index}}
 function deletePoint(){const next=Wave.copy(path);if(Wave.remove(next,selectedPoint)){commit(next);selectedPoint=Math.min(selectedPoint,next.points.length/2-1)}}
 function setKind(kind){const next=Wave.copy(path);next.kinds[selectedPoint]=kind;commit(next)}
 function movePoint(index,x,y){const next=Wave.copy(path);next.points[index*2]=Math.max(-3,Math.min(3,x));next.points[index*2+1]=Math.max(-3,Math.min(3,y));commit(next)}
 function moveHandle(index,handle,x,y){if(path.rounding<=0)return;const next=Wave.copy(path),base=index*4+handle*2;next.kinds[handle===0 ? (index+pointCount-1)%pointCount : index]="smooth";next.handles[base]=Math.max(-6,Math.min(6,(x-next.points[index*2])/path.rounding));next.handles[base+1]=Math.max(-6,Math.min(6,(y-next.points[index*2+1])/path.rounding));commit(next)}
 StudioSection {title:"Editor de Onda libre";expanded:true;headerVisible:panel.framed
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Doble clic en el trazado para insertar. Arrastra puntos y manijas. Supr elimina el punto seleccionado. Cada esquina crea un tramo saliente recto; arrastrar una manija curva su tramo.";color:"#bfaeb6";font.pixelSize:11}
  StudioCombo {Layout.fillWidth:true;objectName:"freeWaveMode";model:["Recto","Suave","Bézier"];currentIndex:["straight","smooth","bezier"].indexOf(panel.path.mode);onActivated:index=>panel.change("mode",["straight","smooth","bezier"][index])}
  RowLayout {Layout.fillWidth:true
   Label {Layout.fillWidth:true;text:"Punto "+(panel.selectedPoint+1);color:"#d5b4c3"}
   StudioToolButton {objectName:"addWavePoint";text:"+";Accessible.name:"Insertar punto después del seleccionado";enabled:panel.pointCount<64;onClicked:panel.insertPoint(panel.selectedPoint,.5)}
   StudioToolButton {objectName:"deleteWavePoint";text:"−";Accessible.name:"Eliminar punto seleccionado";enabled:panel.pointCount>3;onClicked:panel.deletePoint()}
  }
  StudioCombo {Layout.fillWidth:true;objectName:"wavePointKind";visible:panel.path.mode!=="straight";model:["Punto esquina · tramo saliente recto","Punto suave · tramo saliente curvo"];currentIndex:panel.path.kinds[panel.selectedPoint]==="corner" ? 0 : 1;onActivated:index=>panel.setKind(index===0 ? "corner" : "smooth")}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:panel.pointCount+" / 64 puntos"+(panel.advanced ? "" : " · trazado anterior conservado");color:"#db9daf";font.pixelSize:12}
  VisualizerSlider {Layout.fillWidth:true;controller:panel.controller;objectName:"waveRounding";label:"Intensidad de redondeo";explanation:"No altera las posiciones ni elimina las manijas guardadas.";from:0;to:1;decimals:2;enabled:panel.path.mode!=="straight";value:panel.path.rounding;onValueEdited:v=>panel.change("rounding",v)}
  Rectangle {
   id:preview;objectName:"freeWavePreview";Layout.fillWidth:true;Layout.preferredHeight:300;color:"#211c22";radius:6;border.color:"#57404b";clip:true
   readonly property real factor:Math.max(1,Math.min(width,height)/3*panel.zoom)
   function screen(x,y){return {x:width/2+(x-panel.viewCenterX)*factor,y:height/2+(y-panel.viewCenterY)*factor}}
   readonly property var anchorsList:Array.from({length:panel.pointCount},(_,i)=>screen(panel.path.points[i*2],panel.path.points[i*2+1]))
   readonly property var handles:{const p=panel.path,i=panel.selectedPoint;if(p.mode!=="bezier" || p.rounding<=0)return [];return [screen(p.points[i*2]+p.handles[i*4]*p.rounding,p.points[i*2+1]+p.handles[i*4+1]*p.rounding),screen(p.points[i*2]+p.handles[i*4+2]*p.rounding,p.points[i*2+1]+p.handles[i*4+3]*p.rounding)]}
   readonly property var samples:{const result=[],vertices=Curve.readVertices(panel.shapeSettings.visualizerShapeData,"wave","");for(let i=0;i<panel.pointCount;i++)for(let j=0;j<=24;j++){const t=j/24,p=panel.advanced ? Wave.sample(panel.path,i,t) : Curve.pointOnEdge("wave",i,t,vertices,1,1,0,0,0);const s=screen(p.x,p.y);result.push({x:s.x,y:s.y,edge:i,t:t})}return result}
   function nearest(x,y){let best={distance:Infinity,edge:0,t:.5};for(let i=1;i<samples.length;i++){const a=samples[i-1],b=samples[i];if(a.edge!==b.edge)continue;const dx=b.x-a.x,dy=b.y-a.y,u=Math.max(0,Math.min(1,((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy || 1))),d=Math.hypot(x-a.x-u*dx,y-a.y-u*dy);if(d<best.distance)best={distance:d,edge:a.edge,t:a.t+(b.t-a.t)*u}}return best}
   onSamplesChanged:drawing.requestPaint()
   onHandlesChanged:drawing.requestPaint()
   onAnchorsListChanged:drawing.requestPaint()
   Connections {target:panel;function onSelectedPointChanged(){drawing.requestPaint()}}
   Canvas {id:drawing;anchors.fill:parent;onPaint:{const c=getContext("2d");c.clearRect(0,0,width,height);c.strokeStyle="#c97b94";c.lineWidth=2;c.beginPath();for(let i=0;i<preview.samples.length;i++){const p=preview.samples[i];if(i===0)c.moveTo(p.x,p.y);else c.lineTo(p.x,p.y)}c.stroke();const a=preview.anchorsList[panel.selectedPoint];if(a)for(const h of preview.handles){c.strokeStyle="#887b92";c.beginPath();c.moveTo(a.x,a.y);c.lineTo(h.x,h.y);c.stroke();c.fillStyle="#d3bfeb";c.fillRect(h.x-4,h.y-4,8,8)}for(let i=0;i<preview.anchorsList.length;i++){const p=preview.anchorsList[i];c.beginPath();c.arc(p.x,p.y,i===panel.selectedPoint ? 6 : 4,0,Math.PI*2);c.fillStyle=i===panel.selectedPoint ? "#ffd1df" : "#97425d";c.fill()}}}
   MouseArea {
    id:mouseArea;objectName:"freeWaveMouse";anchors.fill:parent;focus:true
    property int dragPoint:-1
    property int dragHandle:-1
    property real grabX:0
    property real grabY:0
    Keys.onDeletePressed:event=>{panel.deletePoint();event.accepted=true}
    onPressed:mouse=>{forceActiveFocus();grabX=mouse.x;grabY=mouse.y;dragPoint=-1;dragHandle=-1;let nearest=10;for(let i=0;i<preview.anchorsList.length;i++){const d=Math.hypot(mouse.x-preview.anchorsList[i].x,mouse.y-preview.anchorsList[i].y);if(d<nearest){nearest=d;dragPoint=i}}for(let h=0;h<preview.handles.length;h++){const d=Math.hypot(mouse.x-preview.handles[h].x,mouse.y-preview.handles[h].y);if(d<nearest){nearest=d;dragHandle=h;dragPoint=-1}}if(dragPoint>=0)panel.selectedPoint=dragPoint;if(dragPoint>=0 || dragHandle>=0)panel.controller.beginTransaction()}
    onPositionChanged:mouse=>{if(!pressed || Math.hypot(mouse.x-grabX,mouse.y-grabY)<2)return;const x=(mouse.x-preview.width/2)/preview.factor+panel.viewCenterX,y=(mouse.y-preview.height/2)/preview.factor+panel.viewCenterY;if(dragHandle>=0)panel.moveHandle(panel.selectedPoint,dragHandle,x,y);else if(dragPoint>=0)panel.movePoint(dragPoint,x,y)}
    onReleased:panel.controller.endTransaction()
    onCanceled:panel.controller.endTransaction()
    onDoubleClicked:mouse=>{const near=preview.nearest(mouse.x,mouse.y);if(near.distance<=14)panel.insertPoint(near.edge,near.t)}
   }
  }
  Repeater {model:["X","Y"];delegate:VisualizerSlider {required property int index;required property string modelData;Layout.fillWidth:true;controller:panel.controller;label:"Punto "+(panel.selectedPoint+1)+" · "+modelData;explanation:"Coordenada relativa a los radios.";from:-3;to:3;decimals:3;value:panel.path.points[panel.selectedPoint*2+index];onValueEdited:v=>{const p=panel.path.points;panel.movePoint(panel.selectedPoint,index===0 ? v : p[panel.selectedPoint*2],index===1 ? v : p[panel.selectedPoint*2+1])}}}
  StudioSection {title:"Precisión y selección de puntos";expanded:false
  StudioCombo {Layout.fillWidth:true;objectName:"wavePointSelector";model:Array.from({length:panel.pointCount},(_,i)=>"Punto "+(i+1));currentIndex:panel.selectedPoint;onActivated:index=>{panel.forceActiveFocus();panel.selectedPoint=index}}
  }
  RowLayout {Layout.fillWidth:true
   StudioButton {text:"Ajustar vista";onClicked:panel.fitView()}
   Label {Layout.fillWidth:true;text:"Zoom "+panel.zoom.toFixed(2)+"×";color:"#bba3af"}
  }
  VisualizerSlider {Layout.fillWidth:true;controller:panel.controller;label:"Zoom de edición";explanation:"Sólo esta vista; no cambia las dimensiones.";from:.25;to:6;decimals:2;suffix:"×";value:panel.zoom;onValueEdited:v=>panel.zoom=v}
 }
 Connections {target:panel.controller;ignoreUnknownSignals:true;function onRestoringChanged(){if(panel.controller.restoring)panel.cancelGesture()}}
}
