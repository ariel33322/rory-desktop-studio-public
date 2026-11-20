import QtQml
import "GeometryEngine.js" as Geometry
import "AudioLayers.js" as Layers
import "PathCuts.js" as Cuts
import "Representation.js" as Representation
import "LayerGeometry.js" as LayerGeometry
import "IndependentCurve.js" as Curve
import "audio-layers" as LegacyLayers
import "audio-particles" as LegacyParticles
import "visualizer-layers" as V2

QtObject {
 id: history
 required property var settings
 property int selectedProfile: 1
 property bool initializeOnCompleted:true
 property string activeManagedProfileId:""
 property var pendingInputSources:[]
 readonly property bool hasPendingInput:pendingInputSources.length>0
 function setInputPending(source,pending){
  if((pendingInputSources.indexOf(source)>=0)===pending)return
  const next=pendingInputSources.filter(item=>item && item!==source)
  if(pending)next.push(source)
  pendingInputSources=next
 }
 function finishPendingInputs(){const sources=pendingInputSources.slice();for(const source of sources)if(source && typeof source.finishForProfile==="function")source.finishForProfile()}

 property var undoStack: []
 property var redoStack: []
 property bool transactionOpen: false
 property bool restoring: false
 property string error: ""
 readonly property var resolution: !V2.VisualizerLayersStore.document && V2.VisualizerLayersStore.migrationError ?
     ({document:null,error:V2.VisualizerLayersStore.migrationError}) : Layers.resolveV2(V2.VisualizerLayersStore.document, Layers.legacySettings(settings,V2.VisualizerLayersStore.legacySnapshot),
     LegacyLayers.AudioLayersStore.data, LegacyParticles.ParticlesStore.data)
 readonly property var document: resolution.document
 readonly property var commonKeys: ({visualizerColor:"color",visualizerOpacity:"opacity"})
 readonly property var barKeys: ({visualizerBarLength:"length",visualizerBarThickness:"thickness",visualizerBarGap:"gap"})
 readonly property var glowKeys: ({visualizerGlow:"glow",visualizerGlowEnabled:"glowEnabled",
     visualizerGlowIntensity:"glowIntensity",visualizerGlowSensitivity:"glowSensitivity",visualizerGlowSmoothing:"glowSmoothing"})
 readonly property var editableKeys: ["visualizerBarCount","visualizerBarLength","visualizerBarThickness","visualizerBarGap",
     "visualizerCenterX","visualizerCenterY","visualizerWidth","visualizerHeight","visualizerRadiusX","visualizerRadiusY",
     "visualizerGeometry","visualizerShapeMode","visualizerIndependentVertices","visualizerShapeData",
     "visualizerOrientation","visualizerScale","visualizerOffset","visualizerIntensity","visualizerSensitivity",
     "visualizerColor","visualizerOpacity","visualizerGlow","visualizerGlowEnabled","visualizerGlowIntensity",
     "visualizerGlowSensitivity","visualizerGlowSmoothing","visualizerSmoothing","visualizerAttack","visualizerBass","visualizerLayersV2","visualizerEnabled","visualizerTestMode","visualizerEffect","visualizerManagedProfileId","visualizerLinearData", ...Object.keys(settings.silenceDefaults)]
 function initialize() {
  if(resolution.error) {error=resolution.error;return false}
  if(!V2.VisualizerLayersStore.document)V2.VisualizerLayersStore.document=JSON.stringify(document)
  return true
 }
 function mapped(key) {return commonKeys[key] || barKeys[key] || glowKeys[key] || key==="visualizerIntensity"}
 function readValue(key) {
  if(key==="visualizerManagedProfileId")return activeManagedProfileId
  if(key==="visualizerLayersV2")return document ? JSON.stringify(document) : ""
  if(mapped(key) && document) {
   const main=Layers.findV2(document,"main")
   if(commonKeys[key])return main.common[commonKeys[key]]
   if(barKeys[key])return main.params.bars[barKeys[key]]
   const type=main.type==="waves" ? "waves" : main.type==="particles" && key==="visualizerIntensity" ? "particles" : "bars"
   return main.params[type][key==="visualizerIntensity" ? "intensity" : glowKeys[key]]
  }
  return settings[key]
 }
 function snapshot() {const result={};for(const key of editableKeys)result[key]=readValue(key);return result}
 function beginTransaction() {
  if(transactionOpen || restoring)return
  const next=undoStack.slice();next.push(snapshot());if(next.length>60)next.shift()
  undoStack=next;redoStack=[];transactionOpen=true
 }
 function endTransaction() {transactionOpen=false}
 function record() {if(!transactionOpen){beginTransaction();endTransaction()}}
 function setDocument(doc) {
  if(restoring)return
  try {
   const encoded=JSON.stringify(Layers.readV2(doc))
   if(encoded===readValue("visualizerLayersV2"))return
   record();V2.VisualizerLayersStore.document=encoded;error=""
  }catch(e){error=String(e.message || e)}
 }
 function editLinear(changes) {
  const next=Object.assign({},settings.visualizerLinear,changes)
  const encoded=JSON.stringify(next)
  if(Geometry.linearConfig(encoded))setValue("visualizerLinearData",encoded)
 }
 function moveSharedGeometry(startX, startY, dx, dy, scale) {
  setValue("visualizerCenterX", Math.max(0, Math.min(1920, startX + dx / scale)))
  setValue("visualizerCenterY", Math.max(0, Math.min(1080, startY + dy / scale)))
 }
 function resizeSharedGeometry(startWidth, startHeight, dx, dy, scale) {
  setValue("visualizerWidth", Math.max(120, Math.min(1400, startWidth + dx / scale)))
  setValue("visualizerHeight", Math.max(120, Math.min(1400, startHeight + dy / scale)))
 }
 function setValue(key,value) {
  if(restoring || readValue(key)===value)return
  if(key==="visualizerLayersV2"){setDocument(value);return}
  if(mapped(key)) {
   const doc=Layers.copy(document),main=Layers.findV2(doc,"main")
   if(commonKeys[key])main.common[commonKeys[key]]=value
   else if(barKeys[key])main.params.bars[barKeys[key]]=value
   else {
    const type=main.type==="waves" ? "waves" : main.type==="particles" && key==="visualizerIntensity" ? "particles" : "bars"
    main.params[type][key==="visualizerIntensity" ? "intensity" : glowKeys[key]]=value
   }
   setDocument(doc);return
  }
  if(editableKeys.indexOf(key)<0)return
  record();settings[key]=value
 }
 function editCommon(id,key,value) {
  if(restoring || !document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(!layer || layer.common[key]===value)return
  layer.common[key]=value;setDocument(doc)
 }
 function editParam(id,type,key,value) {
  if(restoring || !document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(!layer || layer.type!==type || !Object.prototype.hasOwnProperty.call(layer.params[type],key) || layer.params[type][key]===value)return
  if(type==="waves" && key==="mode"){
   const style=value==="pulse" ? "pulse" : value==="spectral" ? "spectral" : "continuous"
   layer.stylePresets.waves[layer.styles.waves]=Layers.copy(layer.params.waves)
   layer.params.waves=layer.stylePresets.waves[style] ? Layers.copy(layer.stylePresets.waves[style]) : Representation.seed(style,layer.params.waves)
   layer.styles.waves=style
  }
  layer.params[type][key]=value;setDocument(doc)
 }
 function editGeometry(id,key,value){
  if(!document || restoring)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id);if(!layer)return
  if(key==="inherited"){
   if(!value && !layer.geometry.custom)layer.geometry.custom=LayerGeometry.capture(settings)
   layer.geometry.inherited=value
  }else{
   if(layer.geometry.inherited || !layer.geometry.custom || !Object.prototype.hasOwnProperty.call(layer.geometry.custom,key))return
   layer.geometry.custom[key]=value
  }
  setDocument(doc)
 }
 function copyLayerGeometry(id){
  if(!document || restoring)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id);if(!layer)return
  layer.geometry={inherited:false,custom:LayerGeometry.capture(settings)};setDocument(doc)
 }
 function editFreeWave(id,path){
  if(restoring)return
  const data=id ? Layers.findV2(document,id) : null
  if(id && (!data || data.geometry.inherited || !data.geometry.custom))return
  const encoded=id ? data.geometry.custom.visualizerShapeData : settings.visualizerShapeData
  const shapes=Curve.parseObject(encoded);shapes.wave=path
  if(!Curve.validVertices(path,"wave")){error="Onda libre inválida";return}
  if(id)editGeometry(id,"visualizerShapeData",JSON.stringify(shapes))
  else setValue("visualizerShapeData",JSON.stringify(shapes))
 }
 function editLayerVertex(id,index,axis,value){
  if(!document || restoring || !Number.isFinite(value) || value < -3 || value >3)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id);if(!layer || layer.geometry.inherited)return
  const g=layer.geometry.custom;if(!g || g.visualizerShapeMode!=="independent" || index<0 || index>=Curve.controlCount(g.visualizerGeometry,g.visualizerShapeData) || (axis!==0 && axis!==1))return
  const points=Curve.readVertices(g.visualizerShapeData,g.visualizerGeometry,g.visualizerIndependentVertices);points[index*2+axis]=value
  g.visualizerShapeData=Curve.writeVertices(g.visualizerShapeData,g.visualizerGeometry,points);setDocument(doc)
 }
 function setCuts(id,cuts){
  if(!document || restoring)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(layer){layer.cuts=cuts;setDocument(doc)}
 }
 function cutRange(id,start,length,shown){
  if(!document)return
  const layer=Layers.findV2(document,id)
  if(layer)try{setCuts(id,Cuts.append(layer.cuts,start,length,shown))}catch(e){error=String(e)}
 }
 function editAnimation(id,key,value){
  if(restoring || !document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(layer && layer.animation[key]!==value){layer.animation[key]=value;setDocument(doc)}
 }
 function setLayerStyle(id,style){
  if(!document || restoring)return
  const type=Representation.kind(style);if(!type)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id);if(!layer)return
  const previous=layer.styles[type]
  if(previous!==style){
   layer.stylePresets[type][previous]=Layers.copy(layer.params[type])
   layer.params[type]=layer.stylePresets[type][style] ? Layers.copy(layer.stylePresets[type][style]) : Representation.seed(style,layer.params[type])
   layer.styles[type]=style
  }
  layer.type=type;setDocument(doc)
 }
 function setLayerType(id,type) {
  if(!document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(layer){layer.type=type;setDocument(doc)}
 }
 function setLayerEnabled(id,enabled) {
  if(!document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id)
  if(layer){layer.enabled=enabled;setDocument(doc)}
 }
 function addLayer(sourceId) {
  if(!document)return ""
  const doc=Layers.copy(document),id=Layers.addV2(doc,sourceId ? Layers.findV2(doc,sourceId) : null)
  if(id)setDocument(doc)
  return id
 }
 function importLegacyParticles(){
  if(!document)return ""
  const doc=Layers.copy(document),seed=Layers.legacyParticleSeed(doc)
  if(!seed)return ""
  const id=Layers.addV2(doc,seed);if(id)setDocument(doc);return id
 }
 function removeLayer(id) {if(!document || id==="main")return;const doc=Layers.copy(document);Layers.removeV2(doc,id);setDocument(doc)}
 function moveLayer(id,delta) {if(!document)return;const doc=Layers.copy(document);Layers.move(doc,id,delta);setDocument(doc)}
 function resetLayer(id) {
  if(!document)return
  const doc=Layers.copy(document),layer=Layers.findV2(doc,id),fresh=Layers.layerV2(id)
  if(!layer)return
  layer.common=fresh.common;layer.params[layer.type]=layer.type==="particles" ? fresh.params.particles : Representation.seed(layer.styles[layer.type],fresh.params[layer.type]);layer.animation=fresh.animation
  if(id==="main"){layer.common.color="#e73858";layer.common.opacity=94}
  setDocument(doc)
 }
 function validateSnapshot(value) {
  if(value.visualizerLinearData!==undefined && !Geometry.linearConfig(value.visualizerLinearData))throw new Error("Geometría lineal inválida")
  for(const key of ["visualizerEnabled","visualizerTestMode","visualizerHideSilentBars"])if(value[key]!==undefined && typeof value[key]!=="boolean")throw new Error("Perfil: activación inválida "+key)
  if(value.visualizerEffect!==undefined && !(settings.visualizerEffects || []).some(effect=>effect.id===value.visualizerEffect))throw new Error("Efecto de perfil desconocido")
  if(value.visualizerManagedProfileId!==undefined && typeof value.visualizerManagedProfileId!=="string")throw new Error("Identificador de perfil inválido")
  const doc=Layers.readV2(value.visualizerLayersV2)
  for(const key of editableKeys) {
   if(key==="visualizerLayersV2" || mapped(key) || value[key]===undefined)continue
   if(typeof settings[key]==="number" && (typeof value[key]!=="number" || !Number.isFinite(value[key])))throw new Error("Perfil: número inválido "+key)
  }
  if(value.visualizerGeometry!==undefined && ["circle","ellipse","square","triangle","star","wave"].indexOf(value.visualizerGeometry)<0)throw new Error("Geometría de perfil desconocida")
  if(value.visualizerShapeMode!==undefined && ["linked","independent"].indexOf(value.visualizerShapeMode)<0)throw new Error("Modo de vértices desconocido")
  const shapes=["circle","ellipse","square","triangle","star","wave"]
  if(value.visualizerShapeData!==undefined){
   const shapeData=Layers.object(value.visualizerShapeData,"Deformaciones del perfil")
   for(const shape of Object.keys(shapeData)){
    if(shapes.indexOf(shape)<0 || !Curve.validVertices(shapeData[shape],shape))throw new Error("Deformación de perfil inválida: "+shape)
   }
  }
  if(value.visualizerIndependentVertices){
   let vertices
   try{vertices=JSON.parse(value.visualizerIndependentVertices)}catch(_){throw new Error("Vértices de perfil inválidos")}
   if(!Array.isArray(vertices) || (vertices.length!==0 && vertices.length!==16) || !vertices.every(number=>Number.isFinite(Number(number))))throw new Error("Vértices de perfil inválidos")
  }
  for(const spec of [["visualizerWidth",120,1400],["visualizerHeight",120,1400],["visualizerRadiusX",60,700],["visualizerRadiusY",60,700],["visualizerScale",.1,4],["visualizerCenterX",0,1920],["visualizerCenterY",0,1080],["visualizerOrientation",-180,180],["visualizerOffset",-300,300],["visualizerBarCount",24,384]])
   if(value[spec[0]]!==undefined)Layers.checkNumber(value[spec[0]],"Perfil "+spec[0],spec[1],spec[2])
  for(const [key,min,max] of [["visualizerSilenceThreshold",.1,30],["visualizerSilenceHold",100,5000],["visualizerSilenceFade",50,2000]])
   if(value[key]!==undefined)Layers.checkNumber(value[key],"Perfil "+key,min,max)
  return doc
 }
 function applySnapshot(value) {
  value=Object.assign({visualizerLinearData:settings.linearDefaults},settings.silenceDefaults,value)
  const doc=validateSnapshot(value)
  restoring=true
  try {
   for(const key of editableKeys)if(key!=="visualizerLayersV2" && key!=="visualizerManagedProfileId" && !mapped(key) && value[key]!==undefined)settings[key]=value[key]
   V2.VisualizerLayersStore.document=JSON.stringify(doc)
   activeManagedProfileId=value.visualizerManagedProfileId || ""
  }finally{restoring=false;transactionOpen=false}
  settings.resetBarSilence()
 }
 function undo() {
  if(!undoStack.length)return
  const next=undoStack.slice(),previous=next.pop(),current=snapshot()
  try {applySnapshot(previous);const redo=redoStack.slice();redo.push(current);redoStack=redo;undoStack=next;error=""}catch(e){error=String(e)}
 }
 function redo() {
  if(!redoStack.length)return
  const next=redoStack.slice(),value=next.pop(),current=snapshot()
  try {applySnapshot(value);const stack=undoStack.slice();stack.push(current);undoStack=stack;redoStack=next;error=""}catch(e){error=String(e)}
 }
 function profileKey() {return "visualizerProfile"+selectedProfile}
 function saveProfile() {
  try {
   const profiles=Layers.object(V2.VisualizerLayersStore.profiles,"Perfiles V2"),value=snapshot()
   validateSnapshot(value);value.version=2;profiles[profileKey()]=value
   V2.VisualizerLayersStore.profiles=JSON.stringify(profiles);error=""
  }catch(e){error=String(e.message || e)}
 }
 function storedProfile(key,legacyOnly){
   const profiles=Layers.object(V2.VisualizerLayersStore.profiles,"Perfiles V2")
   let value=legacyOnly ? null : profiles[key]
   if(!value) {
    const encoded=V2.VisualizerLayersStore.legacySnapshot[key] || settings[key];if(!encoded)return null
    const legacy=Layers.object(encoded,"Perfil anterior")
    value=Object.assign(snapshot(),settings.silenceDefaults,legacy)
    if(legacy.visualizerGeometry===undefined)value.visualizerGeometry="ellipse"
    if(legacy.visualizerShapeData===undefined)value.visualizerShapeData="{}"
    if(legacy.visualizerWidth===undefined)value.visualizerWidth=584
    if(legacy.visualizerHeight===undefined)value.visualizerHeight=550
    const doc=legacy.visualizerLayersV2 ? Layers.readV2(legacy.visualizerLayersV2) : Layers.migrate(value,legacy.visualizerAudioLayers || "",legacy.visualizerParticles || "")
    if(!legacy.visualizerLayersV2)doc.legacy.profile=encoded
    value.visualizerLayersV2=JSON.stringify(doc)
   }
   validateSnapshot(value);return value
 }
 function loadProfile() {
  try {const value=storedProfile(profileKey(),false);if(!value)return;record();applySnapshot(value);error=""}
  catch(e){error=String(e.message || e)}
 }
 Component.onCompleted: if(initializeOnCompleted)Qt.callLater(initialize)
}
