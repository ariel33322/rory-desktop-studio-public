.pragma library
function create(){return {phase:0,energy:0,glowEnergy:0,values:[],scratch:[]}}
function step(state,params,levels,energy,dt){
 dt=Math.max(0,Math.min(.05,dt))
 const retain=params.temporal/100,rate=retain===0 ? 1 : 1-Math.pow(retain,dt/.016)
 const gain=params.sensitivity/100
 const target=Math.max(0,Math.min(1,energy*gain))
 state.energy+=(target-state.energy)*rate
 state.phase=(state.phase+params.speed*dt)%(Math.PI*2)
 if(params.glowEnabled){const g=params.glowSmoothing/100,k=g===0 ? 1 : 1-Math.pow(g,dt/.016);state.glowEnergy+=(energy-state.glowEnergy)*k}
 else state.glowEnergy=0
 if(state.values.length!==levels.length){state.values=Array(levels.length).fill(0);state.scratch=Array(levels.length).fill(0)}
 const radius=Math.round(params.spatial)
 for(let i=0;i<levels.length;i++){
  let sum=0
  for(let j=-radius;j<=radius;j++)sum+=levels[(i+j+levels.length)%levels.length]
  state.scratch[i]=Math.max(0,Math.min(1,sum/(radius*2+1)*gain))
 }
 for(let i=0;i<levels.length;i++)state.values[i]+=(state.scratch[i]-state.values[i])*rate
}
function displacement(state,params,index,count){
 const phase=index/count*Math.PI*2
 let response
 if(params.mode==="pulse")response=state.energy*(.8+.2*Math.sin(state.phase))
 else if(params.mode==="spectral"){
  response=state.values.length ? state.values[Math.min(state.values.length-1,Math.floor(index/count*state.values.length))] : 0
  if(params.representation==="spectrumLine")response-=state.energy*.5
 }
 else {
  const band=state.values.length ? state.values[Math.min(state.values.length-1,Math.floor(index/count*state.values.length))] : 0
  response=state.energy*Math.sin(phase*3+state.phase)+(params.fluidness || 0)*(.35*state.energy*Math.sin(phase*7-state.phase*.7)+.5*(band-state.energy))
 }
 return response*params.amplitude*params.intensity/100*params.direction
}
function draw(ctx,state,params,points,scale,color,opacity,runs){
 if(!state || !points.length || opacity<=0)return
 ctx.save();ctx.shadowBlur=0;ctx.lineJoin="miter";ctx.miterLimit=4;ctx.beginPath()
 const paths=runs || [points]
 for(const path of paths)for(let i=0;i<path.length;i++){
  const point=path[i],offset=displacement(state,params,point.t===undefined ? i : point.t*points.length,points.length)*scale
  if(i===0)ctx.moveTo(point.x+point.nx*offset,point.y+point.ny*offset)
  else ctx.lineTo(point.x+point.nx*offset,point.y+point.ny*offset)
 }
 if(!runs)ctx.closePath();ctx.strokeStyle=color
 if(params.glowEnabled && params.glow>0 && params.glowIntensity>0 && params.glowSensitivity>0){
  const alpha=Math.min(.78,Math.pow(Math.max(0,state.glowEnergy),.65)*params.glowSensitivity/100*params.glowIntensity/100*1.8)*opacity/100
  ctx.lineWidth=(params.thickness+params.glow*4)*scale;ctx.globalAlpha=alpha*.22;ctx.stroke()
  ctx.lineWidth=(params.thickness+params.glow*1.2)*scale;ctx.globalAlpha=alpha*.5;ctx.stroke()
 }
 ctx.lineWidth=params.thickness*scale;ctx.globalAlpha=opacity/100;ctx.stroke();ctx.restore()
}
