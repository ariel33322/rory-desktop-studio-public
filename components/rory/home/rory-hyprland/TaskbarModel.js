.pragma library
.import "RoryTheme.js" as Theme

const modules = ["workspaces", "windows", "launcher", "clock", "audio", "battery", "network", "tray", "media"]
const numbers = {
    width:[24,4096], height:[24,4096], margin:[0,200], spacing:[0,40], x:[0,100], y:[0,100],
    inset:[0,300], opacity:[0,1], borderWidth:[0,8], radius:[0,80], padding:[0,32],
    iconSize:[12,48], textSize:[9,28], shadow:[0,20], duration:[0,1000], delay:[0,3000],
    trigger:[2,30], workspaceGap:[0,30], volumeStep:[1,25]
}
const quickControls=["airplane","dnd","power","record","night","capture","settings","flash"]
const centerCards=["wifi","bluetooth","media","brightness","volume","kde"]
const centerNumbers={width:[280,720],height:[320,1000],x:[-250,250],y:[0,200],
    opacity:[.35,1],borderWidth:[0,6],radius:[0,40],spacing:[4,24],iconSize:[14,34],duration:[0,600]}
function centerDefaults() {
    return {enabled:true,theme:"crimson",width:620,height:820,x:0,y:8,opacity:.95,
        background:"#130a11",border:"#8a2445",accent:"#e94978",borderWidth:1,radius:20,
        spacing:12,iconSize:23,duration:160,decorative:true,decoration:"",
        closeAfterAction:true,openOnHover:false,
        cards:centerCards.map(id=>({id:id,enabled:true})),
        quick:quickControls.map(id=>({id:id,enabled:true}))}
}
function validateSakuraColors(colors, keys) {
    if(colors===undefined)return
    if(!colors || typeof colors!=="object" || Array.isArray(colors)
        || Object.keys(colors).some(key=>!keys.includes(key) || !/^#[0-9a-f]{6}$/i.test(colors[key])))
        throw new Error("Color Sakura inválido")
}
function validateCenter(center) {
    if(center.sakuraLayout!==undefined) {
        const limits={width:[280,500],spacing:centerNumbers.spacing}
        const layout=center.sakuraLayout
        if(!layout || typeof layout!=="object" || Array.isArray(layout) || Object.keys(layout).some(key=>{
            const range=limits[key]
            return !range || !Number.isFinite(layout[key]) || layout[key]<range[0] || layout[key]>range[1]
        }))throw new Error("Medidas Sakura inválidas")
    }
    validateSakuraColors(center.sakuraColors,["background","border","accent"])
    if(center.theme===undefined)center.theme="crimson"
    if(!Theme.valid(center.theme))throw new Error("Tema del centro inválido")
    const defaults=centerDefaults()
    for(const key of Object.keys(defaults))
        if(typeof center[key]!==typeof defaults[key])throw new Error("Ajuste del centro inválido: "+key)
    for(const key of Object.keys(centerNumbers)) {
        const [min,max]=centerNumbers[key]
        if(!Number.isFinite(center[key]) || center[key]<min || center[key]>max)throw new Error("Valor del centro fuera de rango: "+key)
    }
    for(const key of ["background","accent","border"])
        if(!/^#[0-9a-f]{6}$/i.test(center[key]))throw new Error("Color del centro inválido")
    if(center.decoration && !/^(?:file:\/\/\/|\/).+\.(?:png|jpe?g|webp|svg)$/i.test(center.decoration))
        throw new Error("La decoración debe ser una imagen local")
    for(const [key,ids] of [["cards",centerCards],["quick",quickControls]]) {
        const entries=center[key]
        if(!Array.isArray(entries) || entries.length!==ids.length || new Set(entries.map(e=>e?.id)).size!==ids.length
            || entries.some(e=>!ids.includes(e?.id) || typeof e.enabled!=="boolean"))throw new Error("Controles del centro inválidos")
    }
}
function bar(id, name) {
    return {id:id, name:name, enabled:true, theme:"crimson", edge:"bottom", orientation:"horizontal", output:"",
        width:720, height:48, x:50, y:90, margin:8, inset:4, spacing:6, padding:6,
        background:"#231820", opacity:.94, border:"#795164", borderWidth:1, radius:12,
        iconColor:"#f4d9e7", textColor:"#f4e6ee", activeColor:"#824259", iconSize:22, textSize:13,
        shadow:4, blur:false, autohide:false, hideCovered:false, duration:170, delay:500, trigger:4,
        modules:modules.map(id=>({id:id,enabled:id!=="media"})), workspaceGap:4,
        groupWindows:true, favorites:"", launcher:"", date:true, hour24:true, dateFormat:"ddd dd MMM",
        volumeStep:5, hideBattery:true, network:"", hideMedia:true,center:centerDefaults()}
}
function catalog() { return {version:1, layouts:[{id:"global",name:"Global",bars:[]}] } }
function copy(value) { return JSON.parse(JSON.stringify(value)) }
function id(prefix) { return prefix+"-"+Date.now().toString(36)+"-"+Math.random().toString(36).slice(2,11) }
function read(value) {
    if (!value || value.version!==1 || !Array.isArray(value.layouts) || !value.layouts.some(p=>p.id==="global"))
        throw new Error("Catálogo de barras inválido")
    const ids=new Set()
    for (const p of value.layouts) {
        if (!p || typeof p.id!=="string" || !p.id || ids.has(p.id) || typeof p.name!=="string" || !p.name.trim() || !Array.isArray(p.bars))
            throw new Error("Perfil de barras inválido")
        ids.add(p.id)
        const barIds=new Set()
        for (const b of p.bars) {
            if (!b || typeof b.id!=="string" || !b.id || barIds.has(b.id)) throw new Error("Identificador de barra inválido")
            barIds.add(b.id)
            if (typeof b.name!=="string" || !b.name.trim()) throw new Error("Nombre de barra inválido")
            validateSakuraColors(b.sakuraColors,["background","border","iconColor","textColor","activeColor"])
            if(b.theme===undefined)b.theme="crimson"
            if(!Theme.valid(b.theme))throw new Error("Tema de barra inválido")
            if(b.center===undefined)b.center=centerDefaults()
            if(!b.center)throw new Error("Centro de control inválido")
            validateCenter(b.center)
            const defaults=bar(b.id,"Barra")
            for (const key of Object.keys(defaults))
                if (typeof b[key]!==typeof defaults[key]) throw new Error("Ajuste inválido: "+key)
            for (const key of Object.keys(numbers)) {
                const [min,max]=numbers[key]
                if (!Number.isFinite(b[key]) || b[key]<min || b[key]>max) throw new Error("Valor fuera de rango: "+key)
            }
            for (const key of ["background","border","textColor","iconColor","activeColor"])
                if (!/^#[0-9a-f]{6}$/i.test(b[key])) throw new Error("Color inválido: "+key)
            if (!["top","bottom","left","right","free"].includes(b.edge) || !["horizontal","vertical"].includes(b.orientation)
                || !Array.isArray(b.modules) || b.modules.length!==modules.length
                || new Set(b.modules.map(m=>m?.id)).size!==modules.length
                || b.modules.some(m=>!modules.includes(m?.id) || typeof m.enabled!=="boolean"))
                throw new Error("Geometría o módulos inválidos")
        }
    }
    return value
}
function rect(b, w, h) {
    const margin=Math.max(0,Math.min(b.margin,(Math.min(w,h)-1)/2))
    const width=Math.max(1,Math.min(w-2*margin,b.width)), height=Math.max(1,Math.min(h-2*margin,b.height))
    const sx=Math.max(0,w-width-2*margin), sy=Math.max(0,h-height-2*margin)
    const x=b.edge==="left" ? Math.min(b.inset,sx) : b.edge==="right" ? sx-Math.min(b.inset,sx) : sx*b.x/100
    const y=b.edge==="top" ? Math.min(b.inset,sy) : b.edge==="bottom" ? sy-Math.min(b.inset,sy) : sy*b.y/100
    return {x:margin+x,y:margin+y,width:width,height:height,sx:sx,sy:sy}
}
function move(b,g,dx,dy) {
    const clip=(v,m)=>Math.max(0,Math.min(m,v))
    if (g.sx>0) b.x=clip(b.x+100*dx/g.sx,100)
    if (g.sy>0) b.y=clip(b.y+100*dy/g.sy,100)
    if (b.edge!=="free") {
        const horizontal=b.edge==="top" || b.edge==="bottom"
        const delta=horizontal ? dy : dx
        const max=horizontal ? g.sy : g.sx
        b.inset=clip(Math.min(b.inset,max)+delta*(b.edge==="bottom" || b.edge==="right" ? -1 : 1),Math.min(300,max))
    }
    return b
}
function groups(windows, grouped) {
    if (!grouped) return windows.map(w=>({app:w.app,windows:[w]}))
    const byId=new Map()
    for (const w of windows) {
        if (!byId.has(w.app)) byId.set(w.app,{app:w.app,windows:[]})
        byId.get(w.app).windows.push(w)
    }
    return Array.from(byId.values())
}
