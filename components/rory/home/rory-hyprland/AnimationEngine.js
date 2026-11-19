.pragma library
function defaults(){return {enabled:false,mode:"none",speed:1,intensity:20,direction:1,sensitivity:100,smoothing:65}}
function create(){return {mode:"none",phase:0,envelope:0,x:0,y:0,scale:1,rotation:0,filteredX:0,filteredY:0,filteredScale:1,filteredRotation:0,transition:null}}
function angleDelta(a,b){return ((b-a+Math.PI)%(Math.PI*2)+Math.PI*2)%(Math.PI*2)-Math.PI}
function step(state,params,energy,dt){
 if(!params.enabled || params.mode==="none"){
  state.mode="none";state.x=0;state.y=0;state.scale=1;state.rotation=0;state.phase=0;state.transition=null;return
 }
 dt=Math.max(0,Math.min(.05,dt))
 if(state.mode!==params.mode){state.transition={x:state.x,y:state.y,scale:state.scale,rotation:state.rotation,age:0};state.mode=params.mode;state.phase=0}
 const retain=params.smoothing/100,rate=retain===0 ? 1 : 1-Math.pow(retain,dt/.016)
 state.envelope+=(Math.min(1,Math.max(0,energy*params.sensitivity/100))-state.envelope)*rate
 const amount=params.intensity/100
 state.phase=(state.phase+dt*params.speed*params.direction*((params.mode==="rotate" || params.mode==="sway") ? 1+state.envelope : 1)*(params.mode==="rotate" ? Math.PI*2*amount : 1))%(Math.PI*2)
 let x=0,y=0,scale=1,rotation=0
 if(params.mode==="pulse")scale+=.35*amount*state.envelope*(.8+.2*Math.sin(state.phase))
 else if(params.mode==="rotate")rotation=state.phase
 else if(params.mode==="breathe")scale+=.18*amount*(.5+.5*Math.sin(state.phase))*(1+.5*state.envelope)
 else if(params.mode==="sway"){rotation=.22*amount*Math.sin(state.phase);x=8*amount*Math.sin(state.phase);y=4*amount*(Math.cos(state.phase)-1)}
 state.filteredX+=(x-state.filteredX)*rate;state.filteredY+=(y-state.filteredY)*rate
 state.filteredScale+=(scale-state.filteredScale)*rate
 state.filteredRotation+=angleDelta(state.filteredRotation,rotation)*rate
 if(state.transition){
  const from=state.transition;from.age+=dt
  const t=Math.min(1,from.age/.18),ease=t*t*(3-2*t)
  state.x=from.x+(state.filteredX-from.x)*ease;state.y=from.y+(state.filteredY-from.y)*ease
  state.scale=from.scale+(state.filteredScale-from.scale)*ease
  state.rotation=from.rotation+angleDelta(from.rotation,state.filteredRotation)*ease
  if(t===1)state.transition=null
 }else{state.x=state.filteredX;state.y=state.filteredY;state.scale=state.filteredScale;state.rotation=state.filteredRotation}
}
function apply(ctx,state,cx,cy,scale){
 if(!state)return
 ctx.translate(cx+state.x*scale,cy+state.y*scale);ctx.rotate(state.rotation);ctx.scale(state.scale,state.scale);ctx.translate(-cx,-cy)
}
