pragma ComponentBehavior: Bound
import QtQuick
import "IndependentCurve.js" as IndependentCurve
import "AudioLayers.js" as AudioLayers
import "ParticleEngine.js" as ParticleEngine
import "WaveEngine.js" as WaveEngine
import "AnimationEngine.js" as AnimationEngine
import "GeometryEngine.js" as GeometryEngine
import "LayerGeometry.js" as LayerGeometry
import "PathCuts.js" as Cuts
import "Representation.js" as Representation
import "audio-layers" as LegacyLayers
import "audio-particles" as LegacyParticles
import "visualizer-layers" as V2

Item {
 id: spectrumEffect
 required property var settings
 required property real centerX
 required property real centerY
 required property real circleRadiusX
 required property real circleRadiusY
 required property real imageScale
 anchors.fill: parent
 readonly property bool linearMode: settings.visualizerEffect === "linear"
 readonly property var linear: settings.visualizerLinear || GeometryEngine.linearDefaults()
 readonly property var lineFrame: GeometryEngine.linearFrame(linear,width,height)
 readonly property var linearPoints: GeometryEngine.linearPoints(lineFrame,resolvedBarCount())
 readonly property var resolution: !V2.VisualizerLayersStore.document && V2.VisualizerLayersStore.migrationError ?
     ({document:null,error:V2.VisualizerLayersStore.migrationError}) : AudioLayers.resolveV2(V2.VisualizerLayersStore.document,AudioLayers.legacySettings(settings,V2.VisualizerLayersStore.legacySnapshot),
     LegacyLayers.AudioLayersStore.data,LegacyParticles.ParticlesStore.data)
 readonly property var document: resolution.document
 readonly property var renderLayers: document ? document.order.map(id=>AudioLayers.findV2(document,id)).filter(layer=>layer.enabled && Cuts.runs(layer.cuts).length>0) : []
 readonly property var entries: renderLayers.map(layer=>({layer:layer,
     bars:layer.type==="bars" ? layerBarStyle(layer) : null,
     waves:layer.type==="waves" ? Object.assign({},layer.params.waves,{representation:layer.styles.waves}) : null,
     particles:layer.type==="particles" ? Object.assign(AudioLayers.particleConfig(layer),{visibleRuns:Cuts.runs(layer.cuts)}) : null}))
 readonly property string transformKey: JSON.stringify(renderLayers.map(layer=>({id:layer.id,type:layer.type,wave:layer.type==="waves",geometry:layer.geometry,waveCount:layer.type==="waves" ? Math.max(24,Math.round(resolvedBarCount()*layer.params.waves.density/100)) : 0,common:{
     x:layer.common.x,y:layer.common.y,scale:layer.common.scale,rotation:layer.common.rotation,normalOffset:layer.common.normalOffset}})).sort((a,b)=>a.id.localeCompare(b.id)))
 readonly property var barGeometry: buildBarGeometry()
 readonly property bool hasWaves:renderLayers.some(layer=>layer.type==="waves")
 readonly property bool hasBars:renderLayers.some(layer=>layer.type==="bars")
 readonly property var waveGeometry: buildWaveGeometry()
 readonly property var geometryCache: buildGeometryCache()
 readonly property string pathKey: JSON.stringify(renderLayers.filter(layer=>layer.type==="particles").map(layer=>layer.id).sort())
 readonly property var pathCache: buildPaths()
 property var runtimeStates: ({})
 property var levelScratch: []
 property var targetScratch: []
 property var frameScratch: []
 property var responseScratch: []
 property var smoothedLevels: []
 property var smoothedGlowLevels: []
 property var extraGlowLevels: ({})
 property real energy: 0
 property real peak: 0
 property double lastTick: 0
 onEntriesChanged: {
  const next={}
  for(const entry of entries) {
   const previous=runtimeStates[entry.layer.id]
   if(previous && previous.type===entry.layer.type) {
    if(entry.particles && previous.pool && (previous.pool.maximum!==entry.particles.maximum || previous.pool.type!==entry.particles.type))previous.pool=null
    next[entry.layer.id]=previous
   }else if(previous){next[entry.layer.id]={type:entry.layer.type,glow:[],pool:null,wave:null,animation:previous.animation || null}}
  }
  runtimeStates=next
  if(!entries.length)lastTick=0
 }
 onVisibleChanged: if(!visible){runtimeStates=({});lastTick=0}
 function buildWaveGeometry(){return !hasWaves || (IndependentCurve.isSmoothShape(settings.visualizerGeometry) && !(settings.visualizerGeometry==="wave" && IndependentCurve.hasAdvancedWave(settings.visualizerShapeData))) ? barGeometry : GeometryEngine.build(settings,centerX,centerY,circleRadiusX,circleRadiusY,imageScale,resolvedBarCount(),true)}
 readonly property var cutCache: {
  const result={}
  for(const entry of entries){
   const layer=entry.layer,count=resolvedBarCount(),mask=Cuts.mask(layer.cuts,count)
   if(layer.type==="bars" && layer.params.bars.density!==100)for(let i=0;i<count;i++)mask[i]=mask[i] && Representation.sampleEnabled(i,count,layer.params.bars.density)
   result[layer.id]={mask:mask,runs:Cuts.runs(layer.cuts)}
  }
  return result
 }
 readonly property var waveRunCache: {
  const result={}
  for(const entry of entries)if(entry.layer.type==="waves"){
   const geometry=geometryCache[entry.layer.id]
   const runs=cutCache[entry.layer.id].runs
   if(geometry && !(runs.length===1 && runs[0].start===0 && runs[0].end===1))result[entry.layer.id]=Cuts.splitPath(geometry,runs)
  }
  return result
 }
 function layerBarStyle(layer){
  const result=AudioLayers.barStyle(layer)
  result.linear=usesLine(layer)
  if(layer.geometry && !layer.geometry.inherited){const g=LayerGeometry.resolve(settings,layer.geometry);result.radiusX=g.visualizerEffectiveRadiusX*g.visualizerScale*imageScale;result.radiusY=g.visualizerEffectiveRadiusY*g.visualizerScale*imageScale}
  return result
 }
 function usesLine(layer){return linearMode && layer.type==="bars" && (!layer.geometry || layer.geometry.inherited)}
 function sourceGeometry(layer,wave,count){
  if(usesLine(layer))return linearPoints
  if(!layer.geometry || layer.geometry.inherited){
   if(!wave)return barGeometry
   return count===resolvedBarCount() ? waveGeometry : GeometryEngine.build(settings,centerX,centerY,circleRadiusX,circleRadiusY,imageScale,count,true)
  }
  const g=LayerGeometry.resolve(settings,layer.geometry)
  return GeometryEngine.build(g,centerX,centerY,g.visualizerEffectiveRadiusX*g.visualizerScale*imageScale,g.visualizerEffectiveRadiusY*g.visualizerScale*imageScale,imageScale,count,wave)
 }
 function buildGeometryCache() {
  const result={},sources={}
  for(const entry of JSON.parse(transformKey)){
   const line=usesLine(entry)
   const key=JSON.stringify([entry.geometry,entry.wave,entry.waveCount,line])
   if(!sources[key])sources[key]=sourceGeometry(entry,entry.wave,entry.waveCount || resolvedBarCount())
   const cx=line ? (lineFrame.horizontal ? lineFrame.start+lineFrame.length/2 : lineFrame.base) : centerX
   const cy=line ? (lineFrame.horizontal ? lineFrame.base : lineFrame.start+lineFrame.length/2) : centerY
   result[entry.id]=AudioLayers.transformV2(sources[key],cx,cy,line ? 1 : imageScale,entry.common)
  }
  return result
 }
 function buildPaths() {
  const result={}
  for(const id of JSON.parse(pathKey)) {
   const geometry=geometryCache[id]
   if(geometry)result[id]=ParticleEngine.path(geometry)
   else {
    const layer=document ? AudioLayers.findV2(document,id) : null
    if(layer)result[id]=ParticleEngine.path(AudioLayers.transformV2(sourceGeometry(layer,false,resolvedBarCount()),centerX,centerY,imageScale,layer.common))
   }
  }
  return result
 }
 function stateFor(layer) {
  if(!runtimeStates[layer.id])runtimeStates[layer.id]={type:layer.type,glow:[],pool:null,wave:null}
  return runtimeStates[layer.id]
 }
 function advance(dt) {
  if(!visible || !settings.effectiveVisualizerEnabled || !entries.length)return
  const count=resolvedBarCount(),source=settings.spectrum || []
  const next=levelScratch.length===count ? levelScratch : Array(count).fill(0)
  const targets=targetScratch.length===count ? targetScratch : Array(count).fill(0)
  targetScratch=targets
  let sum=0,max=0
  const smoothing=Math.max(0.02,Math.min(0.98,settings.visualizerSmoothing/100))
  const attack=Math.max(0.02,Math.min(0.95,settings.visualizerAttack/100))
  for(let i=0;i<count;i++) {
   const target=settings.visualizerTestMode ? 0.55 : sampleLevel(source,i,count)
   targets[i]=target;sum+=target;max=Math.max(max,target)
   const cached=smoothedLevels.length===count ? Number(smoothedLevels[i]) : target
   const current=Number.isFinite(cached) ? cached : target
   next[i]=current+(target-current)*(target>current ? attack : 1-smoothing)
  }
  energy=sum/count;peak=max
  const extra={}
  for(const entry of entries) {
   const layer=entry.layer,state=stateFor(layer),params=layer.params[layer.type]
   if(layer.type==="bars"){
    if(params.temporal>0){
     if(!state.levels || state.levels.length!==count)state.levels=next.slice()
     const rate=1-Math.pow(params.temporal/100,dt/.016)
     for(let i=0;i<count;i++)state.levels[i]+=(next[i]-state.levels[i])*rate
    }else state.levels=null
    if(layer.styles.bars==="peaks"){
     if(!state.peaks || state.peaks.length!==count)state.peaks=Array(count).fill(0)
     for(let i=0;i<count;i++)state.peaks[i]=Math.max(Math.pow(Math.max(0,next[i]),.78),state.peaks[i]-params.peakDecay/100*dt)
    }else state.peaks=null
   }
   if(layer.animation.enabled && layer.animation.mode!=="none"){
    if(!state.animation)state.animation=AnimationEngine.create()
    AnimationEngine.step(state.animation,layer.animation,energy,dt)
   }else state.animation=null
   if(layer.type==="bars") {
    if(AudioLayers.hasGlow(params)) {
     const values=state.glow.length===count ? state.glow : Array(count).fill(0),existing=state.glow.length===count,rate=Math.max(0.02,1-params.glowSmoothing/100)
     for(let i=0;i<count;i++) {
      const old=existing ? state.glow[i] : targets[i]
      values[i]=old+(targets[i]-old)*rate
     }
     state.glow=values
    }else state.glow=[]
    if(layer.id==="main")smoothedGlowLevels=state.glow
    else extra[layer.id]=state.glow
   }
   if(layer.type==="particles") {
    if(!state.pool)state.pool=ParticleEngine.create(entry.particles.maximum,entry.particles.type)
    ParticleEngine.step(state.pool,entry.particles,pathCache[layer.id],imageScale*layer.common.scale,
        energy*params.intensity/100,peak*params.intensity/100,dt)
   }else if(layer.type==="waves") {
    if(!state.wave)state.wave=WaveEngine.create()
    WaveEngine.step(state.wave,entry.waves,next,energy,dt)
   }
  }
  extraGlowLevels=extra
  const previous=smoothedLevels
  smoothedLevels=next
  levelScratch=previous
 }
    function buildBarGeometry(){return GeometryEngine.build(settings,centerX,centerY,circleRadiusX,circleRadiusY,imageScale,resolvedBarCount(),false)}
    function independentVertices() {
        return IndependentCurve.readVertices(settings.visualizerShapeData,
            settings.visualizerGeometry, settings.visualizerIndependentVertices)
    }
    function independentBarGeometry(index, count, values) {
        return IndependentCurve.barGeometry(index, count, settings.visualizerGeometry, values,
            circleRadiusX, circleRadiusY, centerX, centerY,
            settings.visualizerOrientation)
    }
    function resolvedBarCount() {
        return Math.max(24, Math.min(384,
            Math.round(Number(linearMode ? linear.count : settings.visualizerBarCount) || 24)))
    }
    function sampleLevel(values, index, count) {
        if (!values || values.length === 0)
            return 0
        if (values.length === 1)
            return Math.max(0, Math.min(1, Number(values[0]) / 1000))
        const position = index * (values.length - 1) / (count - 1)
        const lo = Math.floor(position)
        const hi = Math.min(values.length - 1, lo + 1)
        const fraction = position - lo
        const value = Number(values[lo]) * (1 - fraction) + Number(values[hi]) * fraction
        return Math.max(0, Math.min(1, value / 1000))
    }
 Component.onCompleted: Qt.callLater(function(){if(!V2.VisualizerLayersStore.document && document)V2.VisualizerLayersStore.document=JSON.stringify(document)})
 Canvas {
  id: spectrumCanvas
  objectName: "spectrumCanvas"
  anchors.fill: parent
  renderTarget: Canvas.FramebufferObject
        function drawLayer(ctx, layer, geometry, smoothedGlow, frameLevels, responses, cache) {
            const fade = spectrumEffect.settings.barSilenceOpacity
            if (fade <= 0) return
            const style=layer.style,original=style==="rounded" && layer.rounding===100
            const dots=style==="dots",segmented=style==="segmented",peaksStyle=style==="peaks"
            const scale = (layer.linear ? 1 : spectrumEffect.imageScale) * layer.scale
            const rx = (layer.radiusX===undefined ? spectrumEffect.circleRadiusX : layer.radiusX) * layer.scale
            const ry = (layer.radiusY===undefined ? spectrumEffect.circleRadiusY : layer.radiusY) * layer.scale
            const testMode = spectrumEffect.settings.visualizerTestMode
            // Upsample CAVA bins to the user-selected display resolution.
            const count = spectrumEffect.resolvedBarCount()
            const intensity = Math.max(0, Math.min(1.0,
                layer.intensity / 100))
            const glowEnabled = AudioLayers.hasGlow(layer)
            const glowIntensity = Math.max(0, Math.min(1,
                layer.glowIntensity / 100))
            const glowSensitivity = Math.max(0, Math.min(2,
                layer.glowSensitivity / 100))
            const glowRadius = Math.max(0, layer.glow) * scale
            // rx/ry are already in screen pixels; only user spacing and stroke
            // dimensions need the local-to-screen multiplier.
            const slotWidth = 2 * Math.PI * Math.sqrt(rx * ry) / count
            const line = layer.linear ? spectrumEffect.linear : null
            const cell = line ? spectrumEffect.lineFrame.length * scale / count : 0
            const length = line ? Math.max(0, spectrumEffect.lineFrame.depth - (testMode ? 9 : 3)) : layer.length
            const barWidth = line ? Math.max(0.25,Math.min(line.thickness*scale,cell-line.gap*scale)) : Math.max(0.65 * scale, Math.min(
                layer.thickness * scale * Math.max(.05,(slotWidth-layer.gap*scale)/Math.max(.65*scale,slotWidth-3*scale)),
                slotWidth - layer.gap * scale))

            ctx.save()
            ctx.lineCap = layer.style==="classic" || layer.style==="segmented" ? "butt" : "round"
            ctx.lineWidth = barWidth
            ctx.strokeStyle = layer.color
            ctx.shadowColor = layer.color
            ctx.shadowBlur = 0
            ctx.globalAlpha = (layer.opacity / 100) * fade

            const mask=spectrumEffect.cutCache[layer.id].mask
            const localLevels=cache.levels && cache.levels.length===count ? cache.levels : null
            const layerGain=layer.sensitivity/100,customAudio=localLevels!==null || layerGain!==1
            const globalSensitivity=Math.max(.5,Math.min(2,spectrumEffect.settings.visualizerSensitivity/100)),bass=spectrumEffect.settings.visualizerBass/100
            const segments = cache.segments || (cache.segments=[])
            segments.length=0
            // Eight brightness groups share two unblurred strokes each. The halo
            // stays behind the crisp bars; overlapping bars cannot wash out cores.
            const haloGroups = glowEnabled ? (cache.haloGroups || (cache.haloGroups=[[],[],[],[],[],[],[],[]])) : null
            if(haloGroups)for(const group of haloGroups)group.length=0
            for (let i = 0; i < count; ++i) {
                if(!mask[i]){segments.push(0,0,0,0);continue}
                const point = geometry[i]
                const response = !customAudio ? responses[i] : Math.max(0,Math.min(1,(localLevels===null ? responses[i] : Math.pow(Math.max(0,localLevels[i]),.78)*globalSensitivity*(1+bass*(1-i/(count-1))))*layerGain))
                const barLength = (testMode ? 9 + length
                        * response * intensity
                    : 3 + length * response * intensity) * scale

                const startX = point.x, startY = point.y
                const endX = startX + point.nx * barLength * (line ? 1 : layer.direction)
                const endY = startY + point.ny * barLength * (line ? 1 : layer.direction)
                segments.push(startX,startY,endX,endY)
                if (glowEnabled) {
                    let glowLevel = frameLevels[i]
                    if (!testMode) {
                        const glowLevels = smoothedGlow || []
                        const cachedGlow = glowLevels.length === count ? Number(glowLevels[i]) : NaN
                        glowLevel = Number.isFinite(cachedGlow) ? cachedGlow
                            : frameLevels[i]
                    }
                    const glowResponse = Math.max(0, Math.min(1,
                        Math.pow(Math.max(0, glowLevel), 0.65) * glowSensitivity))
                    const glowAlpha = Math.min(0.78, glowResponse * glowIntensity * 1.8)
                        * (layer.glowIndependentOpacity ? 1 : layer.opacity / 100)
                    if (glowAlpha > 0.001) {
                        const bucket = Math.min(7, Math.floor(glowAlpha / 0.78 * 8))
                        haloGroups[bucket].push(i)
                    }
                }
            }

            if (glowEnabled) {
                for (let group = 0; group < haloGroups.length; ++group) {
                    const indices = haloGroups[group]
                    if (!indices.length) continue
                    ctx.beginPath()
                    for (const index of indices) {
                        const offset = index * 4
                        if(dots)Representation.trace(ctx,layer.style,segments[offset],segments[offset+1],segments[offset+2],segments[offset+3],barWidth,layer,scale)
                        else{ctx.moveTo(segments[offset],segments[offset+1]);ctx.lineTo(segments[offset+2],segments[offset+3])}
                    }
                    const alpha = (group + 0.5) / 8 * 0.78
                    ctx.lineWidth = barWidth + glowRadius * 4
                    ctx.globalAlpha = (alpha * 0.22) * fade
                    ctx.stroke()
                    ctx.lineWidth = barWidth + glowRadius * 1.2
                    ctx.globalAlpha = (alpha * 0.5) * fade
                    ctx.stroke()
                }
            }

            for (let i = 0; i < count; ++i) {
                if(!mask[i])continue
                const offset = i * 4
                const startX = segments[offset], startY = segments[offset + 1]
                const endX = segments[offset + 2], endY = segments[offset + 3]
                ctx.beginPath()
                if(dots)Representation.trace(ctx,layer.style,startX,startY,endX,endY,barWidth,layer,scale)
                else{ctx.moveTo(startX,startY);ctx.lineTo(endX,endY)}
                ctx.lineWidth = barWidth
                ctx.globalAlpha = (layer.opacity / 100) * fade
                ctx.shadowBlur = 0
                if(segmented)ctx.setLineDash([layer.segmentSize*scale,layer.segmentGap*scale])
                if(original)ctx.stroke()
                else if(style==="rounded" && layer.rounding<100){ctx.fillStyle=layer.color;Representation.roundedCore(ctx,startX,startY,endX,endY,barWidth,layer.rounding)}
                else if(dots){ctx.fillStyle=layer.color;ctx.fill()}
                else ctx.stroke()
                if(segmented)ctx.setLineDash([])
                if(peaksStyle && cache.peaks){
                 const p=geometry[i],peakLength=(3+length*Math.max(responses[i],cache.peaks[i])*layer.sensitivity/100*intensity)*scale
                 const px=p.x+p.nx*peakLength*(line ? 1 : layer.direction),py=p.y+p.ny*peakLength*(line ? 1 : layer.direction)
                 ctx.beginPath();ctx.moveTo(px-p.ny*barWidth,py+p.nx*barWidth);ctx.lineTo(px+p.ny*barWidth,py-p.nx*barWidth);ctx.lineWidth=Math.max(.8,scale);ctx.stroke()
                }

                // Small, restrained glints are placed on every eighth bar.
                if (i % 16 === 0 && style==="rounded") {
                    const dotRadius = 1.45 * scale
                    ctx.beginPath()
                    ctx.ellipse(endX - dotRadius, endY - dotRadius,
                                dotRadius * 2, dotRadius * 2)
                    ctx.fillStyle = layer.color
                    ctx.globalAlpha = (0.78 * layer.opacity / 100) * fade
                    ctx.shadowBlur = 1.5 * scale
                    ctx.fill()
                    ctx.globalAlpha = (0.94) * fade
                    ctx.shadowBlur = 0
                }
            }
            ctx.restore()
        }
  onPaint: {
   const ctx=getContext("2d")
   ctx.clearRect(0,0,width,height)
   if(width<=0 || height<=0 || !spectrumEffect.entries.length)return
   const count=spectrumEffect.resolvedBarCount(),frameLevels=spectrumEffect.frameScratch,responses=spectrumEffect.responseScratch
   frameLevels.length=0;responses.length=0
   const smoothed=spectrumEffect.smoothedLevels,source=spectrumEffect.settings.spectrum || []
   const testMode=spectrumEffect.settings.visualizerTestMode
   const sensitivity=Math.max(0.5,Math.min(2,spectrumEffect.settings.visualizerSensitivity/100))
   if(spectrumEffect.hasBars)for(let i=0;i<count;i++) {
    const angle=(spectrumEffect.linearMode ? spectrumEffect.linearPoints : spectrumEffect.barGeometry)[i].angle
    const cached=smoothed.length===count ? Number(smoothed[i]) : NaN
    const level=testMode ? 0.56+0.22*Math.sin(angle*2+0.65)+0.14*Math.sin(angle*7-0.9)
        : Number.isFinite(cached) ? cached : spectrumEffect.sampleLevel(source,i,count)
    frameLevels.push(level)
    const bassWeight=1+spectrumEffect.settings.visualizerBass/100*(1-i/(count-1))
    responses.push(Math.max(0,Math.min(1,Math.pow(Math.max(0,level),0.78)*sensitivity*bassWeight)))
   }
   const mainColor=spectrumEffect.document ? AudioLayers.findV2(spectrumEffect.document,"main").common.color : "#e73858"
   for(const entry of spectrumEffect.entries) {
    const layer=entry.layer,state=spectrumEffect.stateFor(layer),geometry=spectrumEffect.geometryCache[layer.id]
    ctx.save()
    if(layer.animation.enabled && layer.animation.mode!=="none" && state && state.animation)
        AnimationEngine.apply(ctx,state.animation,spectrumEffect.centerX+layer.common.x*spectrumEffect.imageScale,
            spectrumEffect.centerY+layer.common.y*spectrumEffect.imageScale,spectrumEffect.imageScale*layer.common.scale)
    if(layer.type==="bars")drawLayer(ctx,entry.bars,geometry,state ? state.glow : [],frameLevels,responses,state)
    else if(layer.type==="particles")ParticleEngine.draw(ctx,state ? state.pool : null,entry.particles,mainColor,spectrumEffect.imageScale*layer.common.scale)
    else if(layer.type==="waves")WaveEngine.draw(ctx,state ? state.wave : null,entry.waves,geometry,spectrumEffect.imageScale*layer.common.scale,layer.common.color,layer.common.opacity,spectrumEffect.waveRunCache[layer.id])
    ctx.restore()
   }
  }
  Connections {
   target: spectrumEffect
   function onSmoothedLevelsChanged(){spectrumCanvas.requestPaint()}
   function onEntriesChanged(){spectrumCanvas.requestPaint()}
   function onGeometryCacheChanged(){spectrumCanvas.requestPaint()}
  }
  Connections {
   target: spectrumEffect.settings
   function onVisualizerColorChanged(){spectrumCanvas.requestPaint()}
   function onVisualizerBarCountChanged(){spectrumCanvas.requestPaint()}
   function onVisualizerTestModeChanged(){spectrumCanvas.requestPaint()}
   function onVisualizerIntensityChanged(){spectrumCanvas.requestPaint()}
   function onVisualizerSensitivityChanged(){spectrumCanvas.requestPaint()}
   function onVisualizerBassChanged(){spectrumCanvas.requestPaint()}
   function onBarSilenceOpacityChanged(){spectrumCanvas.requestPaint()}
  }
 }
 Timer {
  interval:16;repeat:true
  running:spectrumEffect.visible && spectrumEffect.settings.effectiveVisualizerEnabled && spectrumEffect.entries.length>0
      && (!spectrumEffect.settings.visualizerTestMode || spectrumEffect.renderLayers.some(layer=>layer.type!=="bars" || layer.animation.enabled && layer.animation.mode!=="none"))
  onTriggered:{const now=Date.now(),dt=spectrumEffect.lastTick ? Math.min(0.05,(now-spectrumEffect.lastTick)/1000) : 0.016;spectrumEffect.lastTick=now;spectrumEffect.advance(dt)}
 }
}
