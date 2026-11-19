.pragma library
.import "WallpaperIdentity.js" as Wallpaper
function clone(value){return JSON.parse(JSON.stringify(value))}
function stable(value){
 if(Array.isArray(value))return value.map(stable)
 if(value && typeof value==="object"){const result={};for(const key of Object.keys(value).sort())result[key]=stable(value[key]);return result}
 return value
}
function signature(value){return JSON.stringify(stable(value))}
function empty(){return {version:1,nextId:1,order:[],profiles:[],wallpapers:{},activeId:"",legacySources:{}}}
function find(doc,id){return doc.profiles.find(profile=>profile.id===id)}
function nameKey(value){const text=String(value || "").trim();return (text.normalize ? text.normalize("NFC") : text).toLocaleLowerCase()}
function validName(doc,value,exclude){
 const name=String(value || "").trim()
 if(!name || name.length>80)throw new Error("El nombre debe tener entre 1 y 80 caracteres")
 if(doc.profiles.some(profile=>profile.id!==exclude && nameKey(profile.name)===nameKey(name)))throw new Error("Ya existe un perfil con ese nombre")
 return name
}
function uniqueName(doc,base){
 const text=String(base || "Perfil").trim().slice(0,80) || "Perfil";let name=text,n=2
 while(doc.profiles.some(profile=>nameKey(profile.name)===nameKey(name))){const suffix=" ("+n+++")";name=text.slice(0,80-suffix.length)+suffix}
 return name
}
function add(doc,name,snapshot){
 if(doc.profiles.length>=20)throw new Error("Límite de 20 perfiles alcanzado")
 name=validName(doc,name,"");let id
 do{id="profile-"+doc.nextId++}while(find(doc,id))
 doc.profiles.push({id:id,name:name,snapshot:clone(snapshot)});doc.order.push(id);return id
}
function remove(doc,id){
 if(!find(doc,id))throw new Error("El perfil ya no existe")
 doc.profiles=doc.profiles.filter(profile=>profile.id!==id);doc.order=doc.order.filter(value=>value!==id)
 for(const key of Object.keys(doc.wallpapers))if(doc.wallpapers[key]===id)delete doc.wallpapers[key]
 if(doc.activeId===id)doc.activeId=""
}
function read(encoded,validateSnapshot){
 const doc=typeof encoded==="string" ? JSON.parse(encoded) : clone(encoded)
 if(!doc || doc.version!==1 || !Array.isArray(doc.profiles) || doc.profiles.length>20 || !Array.isArray(doc.order) || !Number.isInteger(doc.nextId) || doc.nextId<1)throw new Error("Administrador de perfiles inválido")
 const ids=[],names=[]
 for(const profile of doc.profiles){
  if(!profile || typeof profile.id!=="string" || !/^profile-[1-9][0-9]*$/.test(profile.id) || ids.indexOf(profile.id)>=0)throw new Error("Identificadores de perfil inválidos")
  const key=nameKey(profile.name);if(!key || String(profile.name).trim()!==profile.name || profile.name.length>80 || names.indexOf(key)>=0)throw new Error("Nombres de perfil vacíos o duplicados")
  ids.push(profile.id);names.push(key);if(validateSnapshot)validateSnapshot(profile.snapshot)
 }
 if(doc.order.length!==ids.length || doc.order.some((id,i)=>ids.indexOf(id)<0 || doc.order.indexOf(id)!==i))throw new Error("Orden de perfiles inválido")
 if(typeof doc.activeId!=="string" || doc.activeId && ids.indexOf(doc.activeId)<0)throw new Error("Perfil activo inválido")
 if(!doc.wallpapers || typeof doc.wallpapers!=="object" || Array.isArray(doc.wallpapers))throw new Error("Vínculos de fondos inválidos")
 for(const key of Object.keys(doc.wallpapers))if(Wallpaper.normalize(key)!==key || ids.indexOf(doc.wallpapers[key])<0)throw new Error("Vínculo de fondo inválido")
 return doc
}
