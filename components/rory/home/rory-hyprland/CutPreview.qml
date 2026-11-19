pragma ComponentBehavior: Bound
import QtQuick
import "GeometryEngine.js" as Geometry
import "AudioLayers.js" as Layers
import "PathCuts.js" as Cuts
Rectangle {
 id:preview
 required property var settings
 required property var layerData
 required property var controller
 property real selectionStart:0
 property real selectionLength:.25
 property real zoom:1
 property real panX:0
 property real panY:0
 objectName:"cutPreview"
 property int activeInterval:-1
 signal intervalChosen(int index)
 signal rangeEdited(real start,real length)
 signal barSelected(int index,bool extend)
 signal barToggled(int index)
 implicitHeight:300;color:"#201c22";radius:7;border.color:"#51404b";clip:true
 readonly property int count:Math.max(24,Math.min(384,Math.round(settings.visualizerBarCount)))
 readonly property var sourcePoints:Layers.transformV2(Geometry.build(settings,0,0,settings.visualizerEffectiveRadiusX*settings.visualizerScale,settings.visualizerEffectiveRadiusY*settings.visualizerScale,1,count,false),0,0,1,layerData.common)
 readonly property var points:{
  const raw=sourcePoints;if(!raw.length)return []
  let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity
  for(const p of raw){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
  const factor=Math.min((width-60)/Math.max(1,maxX-minX),(height-60)/Math.max(1,maxY-minY))*zoom
  return raw.map(p=>({x:width/2+panX+(p.x-(minX+maxX)/2)*factor,y:height/2+panY+(p.y-(minY+maxY)/2)*factor,nx:p.nx,ny:p.ny,t:p.t}))
 }
 readonly property var handles:{
  const a=Cuts.pointAt(points,selectionStart),b=Cuts.pointAt(points,Cuts.wrap(selectionStart+selectionLength))
  if(Math.hypot(a.x-b.x,a.y-b.y)<1){b.x+=14;b.y+=14}
  return [a,b]
 }
 readonly property var intervalHandles:{
  const result=[];const intervals=layerData.cuts ? layerData.cuts.intervals : []
  for(let i=0;i<intervals.length;i++){
   const span=intervals[i];if(i===activeInterval || span.length===0)continue
   const a=Cuts.pointAt(points,span.start),b=Cuts.pointAt(points,Cuts.wrap(span.start+span.length))
   if(Math.hypot(a.x-b.x,a.y-b.y)<1){b.x+=14;b.y+=14}
   result.push({x:a.x,y:a.y,index:i,end:0,shown:span.visible},{x:b.x,y:b.y,index:i,end:1,shown:span.visible})
  }
  return result
 }
 function nearest(x,y){let chosen=0,distance=Infinity;for(let i=0;i<points.length;i++){const p=points[i],d=Math.hypot(x-p.x,y-p.y);if(d<distance){chosen=i;distance=d}}return chosen}
 function repaint(){drawing.requestPaint()}
 onPointsChanged:repaint()
 onLayerDataChanged:repaint()
 onSelectionStartChanged:repaint()
 onSelectionLengthChanged:repaint()
 Canvas {
  id:drawing;anchors.fill:parent
  onPaint:{
   const ctx=getContext("2d");ctx.clearRect(0,0,width,height);const points=preview.points
   if(!points.length)return
   const cuts=preview.layerData.cuts || Cuts.defaults()
   for(let i=0;i<points.length;i++){
    const p=points[i],selected=Cuts.contains({start:preview.selectionStart,length:preview.selectionLength},i/points.length)
    ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(p.x+p.nx*8,p.y+p.ny*8)
    const shown=Cuts.visibleAt(cuts,i/points.length)
    ctx.strokeStyle=selected ? (shown ? "#ffd8e2" : "#756572") : shown ? "#c16b85" : "#544b55"
    ctx.lineWidth=selected ? 3 : 2;ctx.stroke()
   }
   for(const p of preview.intervalHandles){ctx.beginPath();ctx.ellipse(p.x-5,p.y-5,10,10);ctx.fillStyle=p.shown ? "#9c4d67" : "#665360";ctx.fill();ctx.strokeStyle="#cdb8c2";ctx.lineWidth=1;ctx.stroke()}
   for(let i=0;i<2;i++){
    const p=preview.handles[i];ctx.beginPath();ctx.ellipse(p.x-7,p.y-7,14,14);ctx.fillStyle=i===0 ? "#8c3651" : "#b6798c";ctx.fill();ctx.strokeStyle="#fff0f4";ctx.lineWidth=2;ctx.stroke()
    ctx.fillStyle="#f5e7ee";ctx.font="12px sans-serif";ctx.fillText(i===0 ? "I" : "F",p.x+10,p.y-8)
   }
  }
 }
 MouseArea {
  id:mouse;objectName:"cutPreviewMouse";anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton;preventStealing:true
  property int endpoint:-1
  property real previousX:0
  property real previousY:0
  onPressed:event=>{
   preview.forceActiveFocus();endpoint=-1;previousX=event.x;previousY=event.y
   if(event.button===Qt.MiddleButton)return
   let other=-1;let nearest=14;for(let i=0;i<2;i++){const distance=Math.hypot(event.x-preview.handles[i].x,event.y-preview.handles[i].y);if(distance<nearest){nearest=distance;endpoint=i}}
   for(const handle of preview.intervalHandles){const d=Math.hypot(event.x-handle.x,event.y-handle.y);if(d<nearest){nearest=d;other=handle.index;endpoint=handle.end}}
   if(event.button===Qt.RightButton){endpoint=-1;preview.barToggled(preview.nearest(event.x,event.y));return}
   if(other>=0)preview.intervalChosen(other)
   if(endpoint>=0)preview.controller.beginTransaction()
   else preview.barSelected(preview.nearest(event.x,event.y),!!(event.modifiers&Qt.ShiftModifier))
  }
  onPositionChanged:event=>{
   if(pressedButtons&Qt.MiddleButton){preview.panX+=event.x-previousX;preview.panY+=event.y-previousY;previousX=event.x;previousY=event.y;return}
   if(!pressed || endpoint<0)return
   const t=preview.nearest(event.x,event.y)/preview.count
   if(endpoint===0){const end=Cuts.wrap(preview.selectionStart+preview.selectionLength);preview.rangeEdited(t,Cuts.wrap(end-t))}
   else preview.rangeEdited(preview.selectionStart,Cuts.wrap(t-preview.selectionStart))
  }
  onReleased:{preview.controller.endTransaction();endpoint=-1}
  onCanceled:{preview.controller.endTransaction();endpoint=-1}
 }
}
