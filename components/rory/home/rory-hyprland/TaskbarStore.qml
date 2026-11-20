pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import "TaskbarModel.js" as Model

Item {
    id: store
    visible: false
    width: 0
    height: 0
    required property url storagePath
    required property var associations
    required property var wallpaperSettings
    property var document: Model.catalog()
    property bool ready: false
    property string error: ""
    property string selected: ""
    property bool dragging: false
    property CrimsonCoordinator crimson: null
    readonly property string profileId: {
        const id=associations.taskbarProfile(wallpaperSettings.activeWallpaper)
        return document.layouts.some(p=>p.id===id) ? id : "global"
    }
    readonly property var layout: document.layouts.find(p=>p.id===profileId)
    readonly property var bars: layout.bars
    readonly property var bar: bars.find(b=>b.id===selected) ?? bars[0] ?? null
    onProfileIdChanged: { selected=""; dragging=false; crimson?.close() }
    Connections { target:store.wallpaperSettings; function onActiveWallpaperChanged(){store.crimson?.close()} }
    Settings { id: saved; location: store.storagePath; category:"Taskbars"; property string data:"" }
    Component.onCompleted: {
        try {
            if (saved.data) document=Model.read(JSON.parse(saved.data))
            ready=true
        } catch(e) { error=String(e.message || e) }
    }
    function change(operation) {
        if (!ready) return false
        try {
            const next=Model.copy(document)
            operation(next)
            Model.read(next)
            saved.data=JSON.stringify(next)
            saved.sync()
            document=next
            error=""
            return true
        } catch(e) { error=String(e.message || e); return false }
    }
    function edit(profile, id, changes) {
        return change(doc=>{
            const b=doc.layouts.find(p=>p.id===profile)?.bars.find(b=>b.id===id)
            if (!b) throw new Error("La barra ya no existe")
            Object.assign(b,changes)
        })
    }
    function create(duplicate) {
        const id=Model.id("barra")
        if (change(doc=>{
            const p=doc.layouts.find(p=>p.id===profileId)
            p.bars.push(duplicate && bar ? Object.assign(Model.copy(bar),{id:id,name:bar.name+" (copia)"})
                : Model.bar(id,"Barra "+(p.bars.length+1)))
        })) selected=id
    }
    function remove(profile,id) {
        return change(doc=>{
            const p=doc.layouts.find(p=>p.id===profile)
            p.bars=p.bars.filter(b=>b.id!==id)
        })
    }
    function saveProfile(name, topLevel) {
        const id=Model.id("perfil")
        const label=String(name).trim()
        if (!label || !change(doc=>doc.layouts.push({id:id,name:label,bars:Model.copy(bars)}))) return false
        return !topLevel || loadProfile(id)
    }
    function loadProfile(id) {
        if (!document.layouts.some(p=>p.id===id)) return false
        return associations.setTaskbarProfile(wallpaperSettings.activeWallpaper,id)
    }
    function useGlobal() { return loadProfile("global") }
}
