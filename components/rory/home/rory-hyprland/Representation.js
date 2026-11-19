.pragma library
function catalog(){return [
 {id:"classic",type:"bars",label:"Barras clásicas"},
 {id:"rounded",type:"bars",label:"Barras redondeadas"},
 {id:"segmented",type:"bars",label:"Barras segmentadas"},
 {id:"continuous",type:"waves",label:"Ondas continuas"},
 {id:"fluid",type:"waves",label:"Ondas fluidas"},
 {id:"spectral",type:"waves",label:"Ondas espectrales"},
 {id:"pulse",type:"waves",label:"Pulsos"},
 {id:"peaks",type:"bars",label:"Espectro de picos"},
 {id:"spectrumLine",type:"waves",label:"Línea de espectro"},
 {id:"dots",type:"bars",label:"Puntos reactivos"}]}
function kind(style){const entry=catalog().find(entry=>entry.id===style);return entry ? entry.type : ""}
function defaultStyle(type,params){return type==="bars" ? "rounded" : params.mode==="pulse" ? "pulse" : params.mode==="spectral" ? "spectral" : "continuous"}
function seed(style,params){
 const result=JSON.parse(JSON.stringify(params))
 if(kind(style)==="waves"){
  result.mode=style==="pulse" ? "pulse" : style==="spectral" || style==="spectrumLine" ? "spectral" : "continuous"
  result.fluidness=style==="fluid" ? .7 : 0
  if(style==="spectrumLine"){result.spatial=0;result.temporal=0}
 }
 return result
}
function validate(layer){
 if(layer.styles===undefined)layer.styles={bars:"rounded",waves:defaultStyle("waves",layer.params.waves)}
 if(!layer.styles || kind(layer.styles.bars)!=="bars" || kind(layer.styles.waves)!=="waves")throw new Error("Estilo incompatible con el motor")
 if(layer.stylePresets===undefined)layer.stylePresets={bars:{},waves:{}}
 if(!layer.stylePresets || !layer.stylePresets.bars || !layer.stylePresets.waves)throw new Error("Presets de estilo inválidos")
 for(const type of ["bars","waves"])for(const style of Object.keys(layer.stylePresets[type])){
  if(kind(style)!==type || !layer.stylePresets[type][style] || typeof layer.stylePresets[type][style]!=="object")throw new Error("Preset de estilo desconocido")
 }
}
function sampleEnabled(index,count,density){const slots=Math.max(1,Math.round(count*density/100));return Math.floor((index+1)*slots/count)>Math.floor(index*slots/count)}
// All styles share the cached bars, audio responses and optimized halo groups.
function trace(ctx,style,x,y,ex,ey,width,params,scale){
 if(style==="dots"){const radius=width*.65;ctx.moveTo(ex+radius,ey);ctx.ellipse(ex-radius,ey-radius,radius*2,radius*2)}
 else{ctx.moveTo(x,y);ctx.lineTo(ex,ey)}
}
function roundedCore(ctx,x,y,ex,ey,width,rounding){
 const length=Math.hypot(ex-x,ey-y),radius=Math.min(width/2,length/2)*rounding/100
 ctx.save();ctx.translate(x,y);ctx.rotate(Math.atan2(ey-y,ex-x));ctx.beginPath()
 const top=-width/2,bottom=width/2
 ctx.moveTo(radius,top);ctx.lineTo(length-radius,top);ctx.quadraticCurveTo(length,top,length,top+radius)
 ctx.lineTo(length,bottom-radius);ctx.quadraticCurveTo(length,bottom,length-radius,bottom)
 ctx.lineTo(radius,bottom);ctx.quadraticCurveTo(0,bottom,0,bottom-radius)
 ctx.lineTo(0,top+radius);ctx.quadraticCurveTo(0,top,radius,top);ctx.closePath();ctx.fill();ctx.restore()
}
