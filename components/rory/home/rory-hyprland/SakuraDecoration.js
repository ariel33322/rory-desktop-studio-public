.pragma library

const limits={
    count:[0,20],fall:[1500,2500],wind:[0,2],shake:[0,2],size:[.55,1.25],opacity:[.2,1],
    leftX:[-40,80],leftY:[0,30],rightX:[-80,40],rightY:[0,30]
}
function defaults() {
    return {enabled:true,animation:true,count:8,fall:2000,wind:1,shake:1,size:1,opacity:.92,
        leftX:0,leftY:0,rightX:0,rightY:0}
}
function read(raw) {
    const value=typeof raw==="string" ? JSON.parse(raw) : raw
    const result=defaults()
    if(!value || typeof value!=="object" || Array.isArray(value))throw new Error("Ajustes Sakura inválidos")
    for(const key of Object.keys(result)){
        if(value[key]===undefined)continue
        if(typeof value[key]!==typeof result[key])throw new Error("Ajuste Sakura inválido: "+key)
        const range=limits[key]
        if(range && (!Number.isFinite(value[key]) || value[key]<range[0] || value[key]>range[1]))
            throw new Error("Ajuste Sakura fuera de rango: "+key)
        result[key]=key==="count" || key==="fall" ? Math.round(value[key]) : value[key]
    }
    return result
}
function particles(origins,settings) {
    if(!origins.length)return []
    return Array.from({length:settings.count},(_,i)=>{
        const origin=origins[i%origins.length], variation=(i*7%19)/18
        return {x:origin.x,y:origin.y,delay:Math.round(i*20+variation*64),
            life:Math.max(1500,Math.min(2500,settings.fall+Math.round((variation-.5)*290))),
            drift:(origin.side*(17+variation*21)+(i%4-1.5)*7)*settings.wind,
            drop:98+variation*52,rotation:(i%2 ? -1 : 1)*(19+variation*39),size:5+variation*7,phase:i*.71}
    })
}
