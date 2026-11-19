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
