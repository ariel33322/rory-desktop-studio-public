import QtQml
import "StudioProfiles.js" as Profiles
import "WallpaperIdentity.js" as Wallpaper
import "AudioLayers.js" as Layers
import "visualizer-layers" as V2
import "studio-profiles" as Store
QtObject {
 id:manager
 required property var controller
 required property var settings
 signal profileRemoved(string id)
 property var associationManager:null
 property bool initialized:false
 property bool updating:false
 property var catalog:null
 property string selectedId:""
 property string error:""
 property var pendingChange:null
 property var pendingLink:null
 property string pendingDelete:""
 property string pendingDeleteName:""
 property string deleteSourceId:""
 property string deleteRevision:""
 readonly property bool deletingActive:pendingDelete!=="" && activeId===pendingDelete
 readonly property bool deleteNeedsDecision:deletingActive && dirty
 readonly property string deleteFallbackId:nextProfileId(pendingDelete)
 readonly property bool deleteRequestCurrent:ready && pendingDelete!=="" && deleteSourceId===activeId
     && !!Profiles.find(catalog,pendingDelete) && deleteRevision===Profiles.signature(Profiles.find(catalog,pendingDelete))
 property string pendingSave:""
 property string lastWallpaperKey:""
 readonly property int count:catalog ? catalog.profiles.length : 0
 readonly property bool ready:initialized && catalog!==null && !!controller
 readonly property string activeId:controller ? controller.activeManagedProfileId : ""
 readonly property var activeProfile:catalog ? Profiles.find(catalog,activeId) || null : null
 readonly property var selectedProfile:catalog ? Profiles.find(catalog,selectedId) || null : null
 readonly property var orderedProfiles:catalog ? catalog.order.map(id=>Profiles.find(catalog,id)) : []
 readonly property string currentSignature:ready && controller.document && !controller.restoring ? fingerprint(controller.snapshot()) : ""
 readonly property bool dirty:ready && (controller.hasPendingInput || !activeProfile || currentSignature!==fingerprint(activeProfile.snapshot))
 readonly property string wallpaperKey:{try{return Wallpaper.normalize(settings.activeWallpaper)}catch(_){return ""}}
 function fail(exception){error=String(exception.message || exception);return false}
 function normalized(value){
  if(!value || typeof value!=="object" || !value.visualizerLayersV2)throw new Error("El perfil no contiene una configuración de capas")
  const result=Object.assign({},controller.snapshot(),settings.silenceDefaults,Layers.copy(value)),doc=controller.validateSnapshot(result)
  result.visualizerLayersV2=JSON.stringify(doc);result.version=2;delete result.visualizerManagedProfileId
  return result
 }
 function fingerprint(value){
  value=Object.assign({},settings.silenceDefaults,value)
  const result={}
  for(const key of controller.editableKeys){
   if(key==="visualizerManagedProfileId" || controller.mapped(key) || value[key]===undefined)continue
   if(key==="visualizerLayersV2"){const doc=Layers.readV2(value[key]);delete doc.legacy;result[key]=doc}
   else result[key]=value[key]
  }
  return Profiles.signature(result)
 }
 function imported(){
  const doc=Profiles.empty(),old=Layers.object(V2.VisualizerLayersStore.profiles,"Perfiles V2 anteriores")
  const slots=Object.keys(old).sort((a,b)=>Number(a.replace("visualizerProfile",""))-Number(b.replace("visualizerProfile","")))
  const legacy={};for(let i=1;i<=3;i++){const key="visualizerProfile"+i;legacy[key]=V2.VisualizerLayersStore.legacySnapshot[key] || settings[key] || ""}
  doc.legacySources={v2:V2.VisualizerLayersStore.profiles,slots:legacy}
  for(const key of slots){
   if(!/^visualizerProfile[1-9][0-9]*$/.test(key))throw new Error("Clave de perfil anterior desconocida: "+key)
   Profiles.add(doc,Profiles.uniqueName(doc,"Perfil "+key.replace("visualizerProfile","")),normalized(old[key]))
  }
  for(let i=1;i<=3;i++){
   const key="visualizerProfile"+i;if(!legacy[key])continue
   const value=normalized(controller.storedProfile(key,true))
   if(old[key] && fingerprint(value)===fingerprint(normalized(old[key])))continue
   Profiles.add(doc,Profiles.uniqueName(doc,"Perfil "+i+(old[key] ? " (anterior)" : "")),value)
  }
  return doc
 }
 function initialize(){
  if(updating)return false
  if(initialized)return true
  try{
   updating=true;initialized=false
   if(!controller.initialize())throw new Error(controller.error || "No se pudo leer la configuración actual")
   const doc=Store.ProfilesStore.data ? Profiles.read(Store.ProfilesStore.data,normalized) : Profiles.read(imported(),normalized)
   if(!doc.activeId){const signature=fingerprint(controller.snapshot()),match=doc.profiles.find(profile=>fingerprint(profile.snapshot)===signature);if(match)doc.activeId=match.id}
   catalog=doc;controller.activeManagedProfileId=doc.activeId;selectedId=doc.activeId || doc.order[0] || ""
   pendingChange=null;pendingLink=null;pendingDelete="";pendingSave="";lastWallpaperKey="";error="";initialized=true
  }catch(e){catalog=null;return fail(e)}finally{updating=false}
  Qt.callLater(handleWallpaperChange);return true
 }
 function commit(doc){const valid=Profiles.read(doc,normalized);Store.ProfilesStore.data=JSON.stringify(valid);catalog=valid;error=""}
 function profileName(id){const profile=catalog ? Profiles.find(catalog,id) : null;return profile ? profile.name : "perfil no disponible"}
 function activateProfile(id){return id===activeId ? true : requestLoad(id,"manual","")}
 function select(id){if(catalog && Profiles.find(catalog,id))selectedId=id}
 function createProfile(name){
  if(!ready)return ""
  try{
   controller.finishPendingInputs()
   const value=normalized(controller.snapshot()),doc=Profiles.clone(catalog),id=Profiles.add(doc,name,value)
   controller.record();updating=true;doc.activeId=id;commit(doc);controller.activeManagedProfileId=id;selectedId=id;return id
  }catch(e){fail(e);return ""}finally{updating=false}
 }
 function renameProfile(id,name){
  if(!ready)return false
  try{const doc=Profiles.clone(catalog),profile=Profiles.find(doc,id);if(!profile)throw new Error("El perfil ya no existe");profile.name=Profiles.validName(doc,name,id);commit(doc);return true}catch(e){return fail(e)}
 }
 function duplicateProfile(id){
  if(!ready)return ""
  try{const doc=Profiles.clone(catalog),source=Profiles.find(doc,id);if(!source)throw new Error("El perfil ya no existe");const added=Profiles.add(doc,Profiles.uniqueName(doc,source.name+" (copia)"),source.snapshot);commit(doc);selectedId=added;return added}catch(e){fail(e);return ""}
 }
 function deleteBlockReason(id){
  if(!ready || !Profiles.find(catalog,id))return "El perfil ya no está disponible."
  // Empty catalogs remain supported for migration/startup, but deleting must
  // leave a valid replacement instead of stranding the active composition.
  return count<2 ? "Crea otro perfil antes de eliminar el último: se necesita un destino válido." : ""
 }
 function canDeleteProfile(id){return deleteBlockReason(id)===""}
 function nextProfileId(id){
  if(!catalog || !id)return ""
  const order=catalog.order.filter(value=>value!==id),index=catalog.order.indexOf(id)
  return order[Math.min(Math.max(0,index),order.length-1)] || ""
 }
 function clearDelete(){pendingDelete="";pendingDeleteName="";deleteSourceId="";deleteRevision=""}
 function requestDelete(id){
  if(!canDeleteProfile(id))return fail(new Error(deleteBlockReason(id)))
  controller.finishPendingInputs();controller.endTransaction()
  const profile=Profiles.find(catalog,id)
  pendingDeleteName=profile.name;deleteSourceId=activeId;deleteRevision=Profiles.signature(profile);pendingDelete=id;error="";showPending();return true
 }
 function cleanHistoryOwners(stack,doc){
  return stack.map(snapshot=>{
   if(!snapshot.visualizerManagedProfileId || Profiles.find(doc,snapshot.visualizerManagedProfileId))return snapshot
   return Object.assign({},snapshot,{visualizerManagedProfileId:""})
  })
 }
 function confirmDelete(confirmed,choice){
  if(!confirmed){const requested=!!pendingDelete;clearDelete();if(requested)error="";return false}
  const id=pendingDelete
  if(!id || !ready)return false
  if(!deleteRequestCurrent)return fail(new Error("El perfil o la selección cambiaron. Cancela y vuelve a abrir Eliminar perfil."))
  if(!canDeleteProfile(id))return fail(new Error(deleteBlockReason(id)))
  controller.finishPendingInputs();controller.endTransaction()
  if(!deleteRequestCurrent)return fail(new Error("El perfil cambió mientras se confirmaban campos pendientes."))
  const changeActive=activeId===id
  if(changeActive && dirty && choice!=="discard" && choice!=="save-copy")return fail(new Error("Elige guardar una copia de los cambios, descartarlos o cancelar."))
  const oldCatalog=catalog,oldData=Store.ProfilesStore.data,before=controller.snapshot(),oldUndo=controller.undoStack,oldRedo=controller.redoStack,oldSelected=selectedId
  let changed=false
  try{
   const doc=Profiles.clone(catalog),profile=Profiles.find(doc,id),fallback=changeActive ? nextProfileId(id) : activeId
   let value=null
   if(changeActive){value=normalized(Profiles.find(doc,fallback).snapshot);value.visualizerManagedProfileId=fallback;controller.validateSnapshot(value)}
   const working=changeActive && dirty && choice==="save-copy" ? normalized(before) : null
   Profiles.remove(doc,id)
   if(working){
    const suffix=" (cambios)";let base=""
    for(const char of profile.name){if(base.length+char.length>80-suffix.length)break;base+=char}
    Profiles.add(doc,Profiles.uniqueName(doc,base+suffix),working)
   }
   doc.activeId=fallback
   // Validate the whole catalog before changing either store or working state.
   Profiles.read(doc,normalized)
   updating=true;changed=true
   if(changeActive){controller.record();controller.applySnapshot(value)}
   commit(doc)
   selectedId=changeActive ? fallback : Profiles.find(doc,selectedId) ? selectedId : fallback || doc.order[0]
   controller.undoStack=cleanHistoryOwners(controller.undoStack,doc);controller.redoStack=cleanHistoryOwners(controller.redoStack,doc)
   if(changeActive || pendingChange && pendingChange.id===id)pendingChange=null
   if(pendingLink && (pendingLink.id===id || pendingLink.previous===id))pendingLink=null
   if(pendingSave===id)pendingSave=""
   clearDelete();profileRemoved(id);return true
  }catch(e){
   if(changed){
    // QML validation/setter failures must not leave a partially applied switch.
    catalog=oldCatalog;Store.ProfilesStore.data=oldData;selectedId=oldSelected
    controller.applySnapshot(before);controller.undoStack=oldUndo;controller.redoStack=oldRedo
   }
   return fail(e)
  }finally{updating=false}
 }
 function saveProfile(id,confirmed){
  if(!ready)return false
  if(id!==activeId && !confirmed){pendingSave=id;return false}
  try{
   controller.finishPendingInputs()
   const doc=Profiles.clone(catalog),profile=Profiles.find(doc,id);if(!profile)throw new Error("Selecciona un perfil existente")
   profile.snapshot=normalized(controller.snapshot());updating=true
   if(activeId!==id)controller.record()
   doc.activeId=id;commit(doc);controller.activeManagedProfileId=id;selectedId=id;pendingSave="";return true
  }catch(e){return fail(e)}finally{updating=false}
 }
 function confirmSave(confirmed){const id=pendingSave;pendingSave="";return confirmed && id ? saveProfile(id,true) : false}
 function performLoad(id){
  try{
   const profile=Profiles.find(catalog,id);if(!profile)throw new Error("El perfil destino ya no existe")
   const value=normalized(profile.snapshot);value.visualizerManagedProfileId=id;controller.validateSnapshot(value)
   controller.record();updating=true;controller.applySnapshot(value)
   const doc=Profiles.clone(catalog);doc.activeId=id;commit(doc);selectedId=id;pendingChange=null;return true
  }catch(e){return fail(e)}finally{updating=false}
 }
 function requestLoad(id,source,key){
  if(!ready || !Profiles.find(catalog,id))return false
  if(activeId===id && (source==="wallpaper" || !dirty))return true
  const staged=controller.hasPendingInput
  if(staged)controller.finishPendingInputs()
  if(dirty || staged || controller.transactionOpen){pendingChange={id:id,source:source || "manual",wallpaper:key || ""};showPending();return false}
  return performLoad(id)
 }
 function resolvePending(choice){
  const pending=pendingChange;if(!pending)return false
  controller.endTransaction()
  if(choice==="cancel"){pendingChange=null;error="";return true}
  if(!ready || !Profiles.find(catalog,pending.id)){pendingChange=null;return fail(new Error("El perfil destino ya no existe"))}
  if(choice!=="save" && choice!=="discard")return false
  if(choice==="save"){
   if(activeProfile){if(!saveProfile(activeId,true))return false}
   else if(!createProfile(Profiles.uniqueName(catalog,"Borrador recuperado")))return false
  }
  const loaded=performLoad(pending.id)
  if(loaded && pending.beforeWallpaper){lastWallpaperKey=pending.wallpaper;settings.imageUrl=pending.url}
  return loaded
 }
 function showPending(){settings.visualizerEditorCollapsed=false;settings.visualizerEditorOpen=true}
 // Called before the gallery applies an image; legacy external changes still use the watcher.
 function requestWallpaper(url){
  if(associationManager)return associationManager.requestWallpaper(url,false)
  if(!ready)return false
  try{
   const key=Wallpaper.normalize(url);if(!key)throw new Error("Fondo inválido")
   const id=catalog.wallpapers[key]
   if(pendingChange && pendingChange.source==="wallpaper")pendingChange=null
   if(id && !requestLoad(id,"wallpaper",key)){
    if(pendingChange)pendingChange=Object.assign({},pendingChange,{beforeWallpaper:true,url:String(url)})
    return false
   }
   lastWallpaperKey=key;settings.imageUrl=url;return true
  }catch(e){return fail(e)}
 }
 function handleWallpaperChange(){
  if(associationManager)return
  if(!ready)return
  try{
   const key=Wallpaper.normalize(settings.imageUrl);if(key===lastWallpaperKey)return
   lastWallpaperKey=key
   // A newer wallpaper supersedes a pending automatic request, never current edits.
   if(pendingChange && pendingChange.source==="wallpaper")pendingChange=null
   const id=key ? catalog.wallpapers[key] : ""
   if(id)requestLoad(id,"wallpaper",key)
  }catch(e){fail(e)}
 }
 function linkWallpaper(id,url,replace){
  if(!ready)return false
  try{
   if(!Profiles.find(catalog,id))throw new Error("Selecciona un perfil existente")
   const key=Wallpaper.normalize(url);if(!key)throw new Error("Selecciona un fondo")
   const previous=catalog.wallpapers[key]
   if(previous && previous!==id && !replace){pendingLink={id:id,key:key,previous:previous};return false}
   const doc=Profiles.clone(catalog);doc.wallpapers[key]=id;commit(doc);pendingLink=null;return true
  }catch(e){return fail(e)}
 }
 function confirmLink(confirmed){const pending=pendingLink;pendingLink=null;return pending && confirmed ? linkWallpaper(pending.id,pending.key,true) : false}
 function unlinkWallpaper(id,key){
  if(!ready || catalog.wallpapers[key]!==id)return false
  try{const doc=Profiles.clone(catalog);delete doc.wallpapers[key];commit(doc);return true}catch(e){return fail(e)}
 }
 function linkedWallpapers(id){return catalog ? Object.keys(catalog.wallpapers).filter(key=>catalog.wallpapers[key]===id).sort() : []}
 function syncActive(){
  if(!ready || updating)return
  try{
   const current=controller.activeManagedProfileId,id=Profiles.find(catalog,current) ? current : "";updating=true
   if(current!==id)controller.activeManagedProfileId=id
   if(catalog.activeId!==id){const doc=Profiles.clone(catalog);doc.activeId=id;commit(doc)}
  }catch(e){fail(e)}finally{updating=false}
 }
 readonly property Connections wallpaperChanges:Connections {target:manager.settings;function onImageUrlChanged(){Qt.callLater(manager.handleWallpaperChange)}}
 readonly property Connections activeChanges:Connections {target:manager.controller;function onActiveManagedProfileIdChanged(){manager.syncActive()}}
 Component.onCompleted:Qt.callLater(initialize)
}
