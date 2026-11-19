.pragma library
.import "IndependentCurve.js" as Curve
function defaults(){return {inherited:true,custom:null}}
function capture(settings){
 const result={}
 for(const key of ["visualizerGeometry","visualizerShapeMode","visualizerShapeData","visualizerIndependentVertices","visualizerWidth","visualizerHeight","visualizerRadiusX","visualizerRadiusY","visualizerOrientation","visualizerOffset","visualizerScale"])result[key]=settings[key]
 return result
}
function validate(value){
 if(value===undefined)return defaults()
 if(!value || typeof value.inherited!=="boolean" || (!value.inherited && !value.custom))throw new Error("Geometría de capa inválida")
 if(value.custom){
  const g=value.custom
  if(["circle","ellipse","square","triangle","star","wave"].indexOf(g.visualizerGeometry)<0 || ["linked","independent"].indexOf(g.visualizerShapeMode)<0)throw new Error("Figura o modo local inválido")
  for(const spec of [["visualizerWidth",120,1400],["visualizerHeight",120,1400],["visualizerRadiusX",60,700],["visualizerRadiusY",60,700],["visualizerOrientation",-180,180],["visualizerOffset",-300,300],["visualizerScale",.1,4]])if(typeof g[spec[0]]!=="number" || !Number.isFinite(g[spec[0]]) || g[spec[0]]<spec[1] || g[spec[0]]>spec[2])throw new Error("Dimensión de capa inválida: "+spec[0])
  const shapes=JSON.parse(g.visualizerShapeData),legacy=JSON.parse(g.visualizerIndependentVertices || "[]")
  if(!shapes || Array.isArray(shapes) || typeof shapes!=="object")throw new Error("Deformaciones locales inválidas")
  for(const shape of Object.keys(shapes))if(["circle","ellipse","square","triangle","star","wave"].indexOf(shape)<0 || !Curve.validVertices(shapes[shape],shape))throw new Error("Vértices locales inválidos")
  if(!Array.isArray(legacy) || legacy.length && !Curve.validVertices(legacy,"ellipse"))throw new Error("Vértices heredados inválidos")
 }
 return value
}
function resolve(settings,value){
 if(!value || value.inherited || !value.custom)return settings
 const g=value.custom
 return Object.assign({},g,{visualizerEffectiveRadiusX:g.visualizerRadiusX*g.visualizerWidth/584,visualizerEffectiveRadiusY:g.visualizerRadiusY*g.visualizerHeight/550,visualizerBarCount:settings.visualizerBarCount})
}
