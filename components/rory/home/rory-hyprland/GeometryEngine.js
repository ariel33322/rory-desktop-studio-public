.pragma library
.import "IndependentCurve.js" as Curve
function build(settings,cx,cy,rx,ry,scale,count,waves){
 const shape=settings.visualizerGeometry
 const custom=(shape==="wave" && Curve.hasAdvancedWave(settings.visualizerShapeData)) || settings.visualizerShapeMode==="independent" && Curve.hasStoredVertices(settings.visualizerShapeData,shape,settings.visualizerIndependentVertices)
 const usePath=shape!=="circle" && shape!=="ellipse" || custom
 const vertices=custom ? Curve.readVertices(settings.visualizerShapeData,shape,settings.visualizerIndependentVertices) : Curve.defaultVertices(shape)
 const gap=(3+settings.visualizerOffset)*scale,result=[]
 if(waves && shape==="wave" && Curve.hasAdvancedWave(settings.visualizerShapeData)){
  const edges=vertices.length/2,perEdge=Math.max(1,Math.floor(count/edges))
  for(let edge=0;edge<edges;edge++)for(let i=0;i<perEdge;i++){
   const p=Curve.pointOnEdge(shape,edge,i/perEdge,vertices,rx,ry,cx,cy,settings.visualizerOrientation)
   result.push({x:p.x+p.nx*gap,y:p.y+p.ny*gap,nx:p.nx,ny:p.ny,angle:0,t:(edge+i/perEdge)/edges})
  }
  return result
 }
 if(waves && !Curve.isSmoothShape(shape)){
  const edges=Curve.controlCount(shape),perEdge=Math.max(1,Math.floor(count/edges)),lengths=[];let total=0
  for(let edge=0;edge<edges;edge++){const n=(edge+1)%edges;const length=Math.hypot((vertices[n*2]-vertices[edge*2])*rx,(vertices[n*2+1]-vertices[edge*2+1])*ry);lengths.push(length);total+=length}
  let distance=0
  for(let edge=0;edge<edges;edge++){
   for(let i=0;i<perEdge;i++){const p=Curve.pointOnEdge(shape,edge,i/perEdge,vertices,rx,ry,cx,cy,settings.visualizerOrientation);result.push({x:p.x+p.nx*gap,y:p.y+p.ny*gap,nx:p.nx,ny:p.ny,angle:0,t:(distance+lengths[edge]*i/perEdge)/Math.max(1e-9,total)})}
   distance+=lengths[edge]
  }
  return result
 }
 for(let i=0;i<count;i++){
  const angle=Math.PI*2*(i+.5)/count-Math.PI/2+settings.visualizerOrientation*Math.PI/180
  let p
  if(usePath)p=Curve.barGeometry(i,count,shape,vertices,rx,ry,cx,cy,settings.visualizerOrientation)
  else{const c=Math.cos(angle),s=Math.sin(angle),n=Math.hypot(c/rx,s/ry);p={x:cx+c*rx,y:cy+s*ry,nx:c/rx/n,ny:s/ry/n}}
  result.push({x:p.x+p.nx*gap,y:p.y+p.ny*gap,nx:p.nx,ny:p.ny,angle:angle,t:i/count})
 }
 return result
}

function linearDefaults() {
 return {direction:"horizontal",edge:"free",x:50,y:70,inset:12,length:700,height:100,thickness:5,gap:3,count:96}
}
function linearConfig(data) {
 let value
 try { value=JSON.parse(data) } catch (_) { return null }
 if(!value || !["horizontal","vertical"].includes(value.direction)
     || !["free","top","bottom","left","right"].includes(value.edge)) return null
 for(const [key,min,max] of [["x",0,100],["y",0,100],["inset",0,4096],["length",24,4096],
     ["height",1,2160],["thickness",1,100],["gap",0,100],["count",24,384]]) {
  if(!Number.isFinite(value[key]) || value[key]<min || value[key]>max) return null
 }
 return Number.isInteger(value.count) ? value : null
}
function linearFrame(config,width,height) {
 const horizontal=config.edge==="free" ? config.direction==="horizontal" : config.edge==="top" || config.edge==="bottom"
 const along=horizontal ? width : height, across=horizontal ? height : width
 const length=Math.min(along,config.length), depth=Math.min(across,config.height)
 const reverse=config.edge==="bottom" || config.edge==="right"
 const offset=Math.min(Math.max(0,across-depth),config.inset)
 const start=(along-length)*(horizontal ? config.x : config.y)/100
 const base=config.edge==="free" ? (across-depth)*(horizontal ? config.y : config.x)/100
     : reverse ? across-offset : offset
 return {horizontal,length,depth,start,base,reverse,along,across}
}
function linearPoints(frame,count) {
 return Array.from({length:count},(_,i)=>{
  const coordinate=frame.start+(i+.5)*frame.length/count, normal=frame.reverse ? -1 : 1
  return {x:frame.horizontal ? coordinate : frame.base,y:frame.horizontal ? frame.base : coordinate,
    nx:frame.horizontal ? 0 : normal,ny:frame.horizontal ? normal : 0,angle:2*Math.PI*i/count,t:i/count}
 })
}
