.pragma library
.import "ParticleEngine.js" as Particles
.import "WaveEngine.js" as Waves
.import "AnimationEngine.js" as Animation
.import "PathCuts.js" as Cuts
.import "Representation.js" as Representation
.import "LayerGeometry.js" as LayerGeometry

function defaults(id) {
    return { id: id, enabled: true, color: "#f15b78", opacity: 65,
        scale: 1.12, intensity: 55, offset: 12, rotation: 0, direction: 1,
        glowEnabled: false, glow: 5, glowIntensity: 42,
        glowSensitivity: 100, glowSmoothing: 62 }
}
function clamp(value, fallback, low, high) {
    const number = Number(value)
    return value !== undefined && Number.isFinite(number)
        ? Math.max(low, Math.min(high, number)) : fallback
}
function read(encoded) {
    let source
    try { source = JSON.parse(encoded || "{}") } catch (_) { source = {} }
    if (!source || typeof source !== "object" || Array.isArray(source)) source = {}
    const result = { version: 1, nextId: Math.round(clamp(source.nextId, 1, 1, 1000000)),
        mainEnabled: source.mainEnabled !== false,
        mainDirection: source.mainDirection === -1 ? -1 : 1, order: [], layers: [] }
    const used = ["main"]
    for (const item of (Array.isArray(source.layers) ? source.layers : []).slice(0, 2)) {
        if (!item || typeof item !== "object") continue
        let id = typeof item.id === "string" && /^layer-[0-9]+$/.test(item.id) ? item.id : ""
        while (!id || used.indexOf(id) >= 0) id = "layer-" + result.nextId++
        used.push(id)
        const layer = defaults(id)
        layer.enabled = item.enabled !== false
        if (typeof item.color === "string" && /^#[0-9a-fA-F]{6}$/.test(item.color)) layer.color = item.color
        for (const spec of [["opacity",0,100],["scale",0.1,3],["intensity",0,100],
                ["offset",-300,300],["rotation",-180,180],["glow",0,16],
                ["glowIntensity",0,100],["glowSensitivity",0,200],["glowSmoothing",0,95]])
            layer[spec[0]] = clamp(item[spec[0]], layer[spec[0]], spec[1], spec[2])
        layer.direction = item.direction === -1 ? -1 : 1
        layer.glowEnabled = item.glowEnabled === true
        result.layers.push(layer)
    }
    for (const id of (Array.isArray(source.order) ? source.order : []))
        if (used.indexOf(id) >= 0 && result.order.indexOf(id) < 0) result.order.push(id)
    for (const id of used) if (result.order.indexOf(id) < 0) result.order.push(id)
    return result
}
function mainStyle(settings, direction) {
    return { id: "main", enabled: true, color: String(settings.visualizerColor),
        opacity: settings.visualizerOpacity, scale: 1,
        intensity: settings.visualizerIntensity, offset: 0, rotation: 0,
        direction: direction, glowEnabled: settings.visualizerGlowEnabled,
        glow: settings.visualizerGlow, glowIntensity: settings.visualizerGlowIntensity,
        glowSensitivity: settings.visualizerGlowSensitivity,
        glowSmoothing: settings.visualizerGlowSmoothing }
}
function hasGlow(layer) {
    return layer.glowEnabled && layer.glow > 0
        && layer.glowIntensity > 0 && layer.glowSensitivity > 0
}
function find(document, id) { return document.layers.find(layer => layer.id === id) }
function add(document, seed) {
    if (document.layers.length >= 2) return ""
    let id
    do { id = "layer-" + document.nextId++ } while (find(document, id))
    const layer = seed ? Object.assign({}, seed, { id: id, enabled: true }) : defaults(id)
    document.layers.push(layer); document.order.push(id)
    return id
}
function remove(document, id) {
    if (id === "main") return
    document.layers = document.layers.filter(layer => layer.id !== id)
    document.order = document.order.filter(value => value !== id)
}
function move(document, id, delta) {
    const index = document.order.indexOf(id), next = index + delta
    if (index < 0 || next < 0 || next >= document.order.length) return
    document.order.splice(index, 1); document.order.splice(next, 0, id)
}
function transform(points, cx, cy, imageScale, layer) {
    const angle = layer.rotation * Math.PI / 180
    const cos = Math.cos(angle), sin = Math.sin(angle)
    return points.map(point => {
        const x = (point.x - cx) * layer.scale, y = (point.y - cy) * layer.scale
        const nx = point.nx * cos - point.ny * sin
        const ny = point.nx * sin + point.ny * cos
        return { x: cx + x * cos - y * sin + nx * layer.offset * imageScale,
            y: cy + x * sin + y * cos + ny * layer.offset * imageScale,
            nx: nx, ny: ny, angle: point.angle, t:point.t }
    })
}

// V2 leaves V1 readers available for recovery; it never writes legacy stores.
function copy(value) { return JSON.parse(JSON.stringify(value)) }
function object(encoded, label) {
    if (!encoded) return {}
    let value
    try { value = typeof encoded === "string" ? JSON.parse(encoded) : copy(encoded) }
    catch (_) { throw new Error(label + ": JSON inválido") }
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(label + ": se esperaba un objeto")
    return value
}
function checkNumber(value, label, low, high) {
    if (typeof value !== "number" || !Number.isFinite(value) || value < low || value > high)
        throw new Error(label + ": valor fuera de rango")
}
function waveDefaults() {
    return { mode: "continuous", amplitude: 18, thickness: 2.2, speed: 1,
        sensitivity: 100, spatial: 1, temporal: 55, intensity: 55, direction: 1, fluidness:0, density:100,
        glowEnabled: false, glow: 5, glowIntensity: 42, glowSensitivity: 100, glowSmoothing: 62 }
}
function layerV2(id) {
    const particles = Particles.defaults()
    particles.mode = particles.type; delete particles.type; delete particles.enabled
    delete particles.opacity; delete particles.color
    particles.intensity = 100
    return { id: id, name: id === "main" ? "Principal" : "Capa " + id.replace("layer-", ""),
        type: "bars", enabled: true, geometry:LayerGeometry.defaults(), styles:{bars:"rounded",waves:"continuous"},stylePresets:{bars:{},waves:{}}, cuts:Cuts.defaults(), animation: Animation.defaults(),
        common: { color: "#f15b78", opacity: 65, x: 0, y: 0, scale: 1, rotation: 0, normalOffset: 0 },
        params: { bars: { sensitivity:100, temporal:0, density:100, rounding:100, segmentSize:5, segmentGap:3, peakDecay:55, intensity: 55, length: 52, thickness: 5, gap: 3, direction: 1,
            glowEnabled: false, glow: 5, glowIntensity: 42, glowSensitivity: 100,
            glowSmoothing: 62, glowIndependentOpacity: false },
            particles: particles, waves: waveDefaults() } }
}
function readV2(encoded) {
    const doc = object(encoded, "Capas V2")
    if (doc.version !== 2) throw new Error("Versión de capas no compatible")
    if (!Array.isArray(doc.layers) || doc.layers.length < 1 || doc.layers.length > 4) throw new Error("Se requieren entre 1 y 4 capas")
    const ids = []
    for (const source of doc.layers) {
        if (!source || typeof source.id !== "string" || !/^(main|layer-[0-9]+)$/.test(source.id) || ids.indexOf(source.id) >= 0)
            throw new Error("Identificadores de capa inválidos o duplicados")
        ids.push(source.id)
        if (["bars","particles","waves"].indexOf(source.type) < 0) throw new Error("Tipo de visualización desconocido")
        if (typeof source.enabled !== "boolean") throw new Error("Activación de capa inválida")
        const defaults = layerV2(source.id)
        source.cuts=Cuts.validate(source.cuts)
        source.geometry=LayerGeometry.validate(source.geometry)
        source.animation=Object.assign(Animation.defaults(),source.animation || {})
        const animation=source.animation
        if(typeof animation.enabled!=="boolean" || ["none","pulse","rotate","breathe","sway"].indexOf(animation.mode)<0 || (animation.direction!==1 && animation.direction!==-1))throw new Error("Animación inválida")
        for(const spec of [["speed",0,5],["intensity",0,100],["sensitivity",0,250],["smoothing",0,95]])checkNumber(animation[spec[0]],"Animación "+spec[0],spec[1],spec[2])
        source.name = source.name === undefined ? defaults.name : String(source.name)
        source.common = Object.assign(defaults.common, source.common || {})
        const c = source.common
        if (!/^#[0-9a-fA-F]{6}$/.test(c.color)) throw new Error("Color de capa inválido")
        for (const spec of [["opacity",0,100],["x",-1920,1920],["y",-1080,1080],["scale",0.1,4],["rotation",-180,180],["normalOffset",-300,300]])
            checkNumber(c[spec[0]], "Capa " + source.id + " " + spec[0], spec[1], spec[2])
        source.params = source.params || {}
        for (const type of ["bars","particles","waves"]) source.params[type] = Object.assign(defaults.params[type],source.params[type] || {})
        Representation.validate(source)
        const bars = source.params.bars, particles = source.params.particles, waves = source.params.waves
        for(const spec of [["sensitivity",0,250],["temporal",0,95],["density",5,100],["rounding",0,100],["segmentSize",1,24],["segmentGap",1,16],["peakDecay",1,200]])checkNumber(bars[spec[0]],"Estilo barras "+spec[0],spec[1],spec[2])
        checkNumber(waves.fluidness,"Fluidez",0,1);checkNumber(waves.density,"Densidad de ondas",5,100)
        // Validate inactive presets as strictly as the active parameters, without truncation.
        for(const type of ["bars","waves"])for(const style of Object.keys(source.stylePresets[type])){
         const probe=layerV2("main");probe.params[type]=source.stylePresets[type][style]
         readV2({version:2,order:["main"],layers:[probe]})
        }
        for (const spec of [["intensity",0,100],["length",0,300],["thickness",0.1,24],["gap",0,20]]) checkNumber(bars[spec[0]],"Barras "+spec[0],spec[1],spec[2])
        if (["sparks","dust","orbit"].indexOf(particles.mode)<0) throw new Error("Modo de partículas inválido")
        for (const spec of [["maximum",8,192],["size",0.5,8],["speed",0,240],["sensitivity",0,250],["life",0.2,6],["dispersion",0,180],["intensity",0,100]])
            checkNumber(particles[spec[0]],"Partículas "+spec[0],spec[1],spec[2])
        if (!Number.isInteger(particles.maximum)) throw new Error("Máximo de partículas debe ser entero")
        if (["continuous","pulse","spectral"].indexOf(waves.mode)<0) throw new Error("Modo de onda inválido")
        for (const spec of [["amplitude",0,120],["thickness",0.5,12],["speed",0,5],["sensitivity",0,250],["spatial",0,4],["temporal",0,95],["intensity",0,100]])
            checkNumber(waves[spec[0]],"Ondas "+spec[0],spec[1],spec[2])
        for (const params of [bars,waves]) {
            if (params.direction!==1 && params.direction!==-1) throw new Error("Dirección inválida")
            for (const spec of [["glow",0,16],["glowIntensity",0,100],["glowSensitivity",0,200],["glowSmoothing",0,95]])
                checkNumber(params[spec[0]],"Glow "+spec[0],spec[1],spec[2])
        }
    }
    if (ids.indexOf("main")<0) throw new Error("Falta la capa principal")
    if (!Array.isArray(doc.order) || doc.order.length!==ids.length || doc.order.some((id,index)=>ids.indexOf(id)<0 || doc.order.indexOf(id)!==index))
        throw new Error("Orden de capas inválido")
    doc.nextId = Number.isInteger(doc.nextId) && doc.nextId>0 ? doc.nextId : 1
    return doc
}
function findV2(doc,id) { return doc.layers.find(layer=>layer.id===id) }
function addV2(doc,seed) {
    if (doc.layers.length>=4) return ""
    let id
    do { id="layer-"+doc.nextId++ } while(findV2(doc,id))
    const layer=seed ? copy(seed) : layerV2(id)
    layer.id=id;layer.name="Capa "+id.slice(6)
    doc.layers.push(layer);doc.order.push(id);return id
}
function removeV2(doc,id) {
    if(id==="main")return
    doc.layers=doc.layers.filter(layer=>layer.id!==id);doc.order=doc.order.filter(value=>value!==id)
}
function migrate(settings, layersEncoded, particlesEncoded) {
    const raw = object(layersEncoded,"Capas anteriores")
    const rawParticles = object(particlesEncoded,"Partículas anteriores")
    if (raw.version!==undefined && raw.version!==1) throw new Error("Versión anterior de capas desconocida")
    if (rawParticles.version!==undefined && rawParticles.version!==1) throw new Error("Versión anterior de partículas desconocida")
    const oldLayers=raw.layers===undefined ? [] : raw.layers
    if (!Array.isArray(oldLayers) || oldLayers.length>2) throw new Error("Conflicto: capas anteriores exceden el formato V1")
    const ids=["main"]
    for (const layer of oldLayers) {
        if (!layer || typeof layer.id!=="string" || !/^layer-[0-9]+$/.test(layer.id) || ids.indexOf(layer.id)>=0) throw new Error("Conflicto de identificadores V1")
        ids.push(layer.id)
    }
    if (raw.order && (!Array.isArray(raw.order) || raw.order.length!==ids.length || raw.order.some((id,i)=>ids.indexOf(id)<0 || raw.order.indexOf(id)!==i)))
        throw new Error("Conflicto de orden V1")
    const old=read(layersEncoded), legacyParticles=Particles.read(particlesEncoded)
    const doc={version:2,nextId:old.nextId,order:old.order.slice(),layers:[],legacy:{layers:layersEncoded || "",particles:particlesEncoded || ""}}
    const main=layerV2("main"),style=mainStyle(settings,old.mainDirection)
    function importBars(target,source) {
        target.common.color=source.color;target.common.opacity=source.opacity
        target.common.scale=source.scale;target.common.rotation=source.rotation;target.common.normalOffset=source.offset
        for(const key of ["intensity","direction","glowEnabled","glow","glowIntensity","glowSensitivity","glowSmoothing"])target.params.bars[key]=source[key]
        target.params.bars.length=Number(settings.visualizerBarLength)
        target.params.bars.thickness=Number(settings.visualizerBarThickness)
        target.params.bars.gap=Number(settings.visualizerBarGap)
    }
    importBars(main,style);main.enabled=old.mainEnabled;main.params.bars.glowIndependentOpacity=true
    // Store the dormant global particle settings even when no new layer is needed.
    const particleParams=copy(legacyParticles)
    particleParams.mode=particleParams.type;delete particleParams.type;delete particleParams.enabled
    delete particleParams.color;delete particleParams.opacity
    main.params.particles=Object.assign(main.params.particles,particleParams)
    doc.layers.push(main)
    for(const source of old.layers) {const target=layerV2(source.id);importBars(target,source);target.enabled=source.enabled;doc.layers.push(target)}
    if(legacyParticles.enabled) {
        const id=addV2(doc),layer=findV2(doc,id)
        if(!id)throw new Error("Conflicto: no hay espacio para partículas anteriores")
        layer.type="particles";layer.name="Partículas importadas"
        layer.params.particles=copy(main.params.particles)
        layer.common.color=legacyParticles.color;layer.common.opacity=legacyParticles.opacity
    }
    return readV2(doc)
}
function resolveV2(encoded,settings,layers,particles) {
    try {return {document:encoded ? readV2(encoded) : migrate(settings,layers,particles),error:""}}
    catch(error){return {document:null,error:String(error.message || error)}}
}
function particleConfig(layer) {
    const cfg=copy(layer.params.particles)
    cfg.type=cfg.mode;cfg.enabled=layer.enabled
    cfg.color=layer.common.color;cfg.opacity=layer.common.opacity
    return cfg
}
function barStyle(layer) {
    return Object.assign({},layer.params.bars,{style:layer.styles.bars,id:layer.id,color:layer.common.color,opacity:layer.common.opacity,scale:layer.common.scale})
}
function transformV2(points,cx,cy,scale,c) {
    if(c.scale===1 && c.rotation===0 && c.normalOffset===0 && c.x===0 && c.y===0)return points
    return transform(points,cx,cy,scale,{scale:c.scale,rotation:c.rotation,offset:c.normalOffset})
        .map(point=>({x:point.x+c.x*scale,y:point.y+c.y*scale,nx:point.nx,ny:point.ny,angle:point.angle,t:point.t}))
}

function legacyParticleSeed(doc){
 if(!doc.legacy || !doc.legacy.particles)return null
 const config=Particles.read(doc.legacy.particles),layer=layerV2("main")
 layer.type="particles";layer.common.color=config.color;layer.common.opacity=config.opacity
 const params=copy(config);params.mode=params.type;delete params.type;delete params.enabled;delete params.color;delete params.opacity
 layer.params.particles=Object.assign(layer.params.particles,params)
 return layer
}

function readLegacyIni(text){
 const result={};let inSection=false
 for(const line of String(text || "").split(/\r?\n/)){
  const trimmed=line.trim()
  if(trimmed[0]==="["){inSection=trimmed==="[RoryWallpaper]";continue}
  if(!inSection || !trimmed || trimmed[0]===";" || trimmed[0]==="#")continue
  const split=trimmed.indexOf("=");if(split<0)continue
  const key=trimmed.slice(0,split);if(key.indexOf("visualizer")!==0)continue
  let value=trimmed.slice(split+1)
  if(value[0]==='"'){
   try{value=JSON.parse(value)}catch(_){throw new Error("Valor INI inválido: "+key)}
  }else if(value==="true" || value==="false")value=value==="true"
  else if(value!=="" && Number.isFinite(Number(value)) && value[0]!=="#")value=Number(value)
  result[key]=value
 }
 return result
}
function legacySettings(settings,persisted){
 const result={}
 for(const key of ["visualizerColor","visualizerOpacity","visualizerIntensity","visualizerGlowEnabled","visualizerGlow","visualizerGlowIntensity","visualizerGlowSensitivity","visualizerGlowSmoothing","visualizerBarLength","visualizerBarThickness","visualizerBarGap"])
  result[key]=persisted && persisted[key]!==undefined ? persisted[key] : settings[key]
 return result
}
