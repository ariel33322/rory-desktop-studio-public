.pragma library
// Lexical local-file identity; case and literal percent characters are preserved.
function normalize(value,allowRoot){
 const source=String(value || "");if(!source.trim())return ""
 let path
 if(/^file:/i.test(source)){
  if(!/^file:\/\/(?:localhost)?\//i.test(source))throw new Error("El vínculo requiere un archivo local")
  const encoded=source.replace(/^file:\/\/(?:localhost)?/i,"").split(/[?#]/)[0]
  path=decodeURIComponent(encoded)
 }else{if(source[0]!=="/")throw new Error("Se requiere una ruta absoluta");path=source}
 const parts=[]
 for(const part of path.split("/")){if(!part || part===".")continue;if(part===".."){parts.pop();continue}parts.push(part)}
 if(!parts.length){if(allowRoot)return "file:///";throw new Error("Selecciona un archivo de fondo")}
 return "file://"+encodeURI("/"+parts.join("/")).replace(/#/g,"%23").replace(/\?/g,"%3F")
}
function label(value){try{return decodeURIComponent(String(value).replace(/^file:\/\//i,""))}catch(_){return String(value)}}
