pragma ComponentBehavior: Bound
import QtQml
import "StudioProfiles.js" as Profiles
import "WallpaperIdentity.js" as Wallpaper

QtObject {
    id: manager
    required property ClockSettings settings
    // StudioProfileBar and StudioColorEditor share this controller contract.
    readonly property var controller: QtObject {
        property var pendingInputs: []
        property bool transactionOpen:false
        function beginTransaction() {transactionOpen=true}
        function endTransaction() { finishPendingInputs();transactionOpen=false }
        function setInputPending(input, pending) {
            pendingInputs = pendingInputs.filter(item => item !== input)
            if (pending) pendingInputs = pendingInputs.concat([input])
        }
        function finishPendingInputs() {
            for (const input of pendingInputs.slice()) if (input) input.finishForProfile()
        }
    }
    signal profileRemoved(string id)
    property var catalog: null
    property string error: ""
    property var pendingChange: null
    property string pendingSave: ""
    property string pendingDelete: ""
    readonly property bool ready: catalog !== null
    readonly property int count: catalog ? catalog.profiles.length : 0
    readonly property string activeId: catalog ? catalog.activeId : ""
    readonly property var activeProfile: catalog ? Profiles.find(catalog, activeId) || null : null
    readonly property var orderedProfiles: catalog ? catalog.order.map(id => Profiles.find(catalog, id)) : []
    readonly property var savedSnapshot: activeProfile ? activeProfile.snapshot : catalog?.detachedBaseline
    readonly property bool dirty: ready && (!savedSnapshot
        || Profiles.signature(settings.snapshot()) !== Profiles.signature(savedSnapshot))

    function fail(e) { error = String(e.message || e); return false }
    function validate(value) {
        if (!value || typeof value !== "object") throw new Error("Configuración de reloj inválida")
        // Added fields receive defaults; malformed old fields still fail validation.
        const additions = Object.assign({}, settings.outlineDefaults, {
            elementsData: "",
            customWidth: 0,
            customHeight: 0,
            fontFamily: "Noto Sans",
            fontWeight: 300,
            clockRotation: 0,
            showSeconds: false,
            showDate: true,
            elementSpacing: 9,
            horizontalAlignment: 1,
            verticalAlignment: 0,
            backgroundEnabled: false,
            backgroundColor: "#10090f",
            backgroundOpacity: 0.7,
            backgroundRadius: 10,
            backgroundImage: "",
            backgroundX: 0,
            backgroundY: 0,
            backgroundWidth: 0,
            backgroundHeight: 0,
            backgroundScale: 1,
            backgroundRotation: 0,
            backgroundFit: "cover"
        })
        for (const key of Object.keys(additions)) if (value[key] === undefined) value[key] = additions[key]
        if (typeof value.backgroundImage === "string" && value.backgroundImage)
            value.backgroundImage = Wallpaper.normalize(value.backgroundImage)
        if (["contain","cover","stretch","original"].indexOf(value.backgroundFit)<0) throw new Error("Ajuste de imagen inválido")
        if (value.backgroundImage && !/^file:\/\/\/.*\.(png|jpe?g|webp)$/i.test(value.backgroundImage)) throw new Error("Imagen del reloj inválida")
        const limits = {outlineWidth:[0.5,8],outlineOpacity:[0,1],timeSize:[8,300],widgetOpacity:[0,1],leftPercent:[0,1],topPercent:[0,1],customWidth:[0,4096],customHeight:[0,4096],fontWeight:[100,900],clockRotation:[-180,180],elementSpacing:[0,100],horizontalAlignment:[0,2],verticalAlignment:[0,2],backgroundOpacity:[0,1],backgroundRadius:[0,500],backgroundX:[-4096,4096],backgroundY:[-4096,4096],backgroundWidth:[0,4096],backgroundHeight:[0,4096],backgroundScale:[0.05,10],backgroundRotation:[-180,180]}
        const current = settings.snapshot()
        for (const key of settings.editableKeys) {
            if (typeof value[key] !== typeof current[key]) throw new Error("Propiedad inválida: " + key)
            if (limits[key] && (!Number.isFinite(value[key]) || value[key] < limits[key][0] || value[key] > limits[key][1])) throw new Error("Valor fuera de rango: " + key)
            if (["accent","textColor","backgroundColor"].indexOf(key)>=0 && !/^#[0-9a-fA-F]{6}$/.test(value[key])) throw new Error("Color inválido: " + key)
        }
        if (value.outlineColor && !/^#[0-9a-fA-F]{6}$/.test(value.outlineColor)) throw new Error("Color de contorno inválido")
        if (value.elementsData && !settings.readElements(value.elementsData)) throw new Error("Elementos de reloj inválidos")
        return value
    }
    function commit(doc) {
        const valid = Profiles.read(doc, validate)
        if (valid.detachedBaseline) validate(valid.detachedBaseline)
        settings.profilesData = JSON.stringify(valid)
        catalog = valid; error = ""
    }
    function initialize() {
        if (ready) return
        try {
            if (settings.profilesData) {
                const doc = Profiles.read(settings.profilesData, validate)
                if (!doc.activeId && !doc.detachedBaseline) {
                    const sig = Profiles.signature(settings.snapshot())
                    const match = doc.profiles.find(p => Profiles.signature(p.snapshot) === sig)
                    if (match) {
                        doc.activeId = match.id
                        commit(doc)
                        return
                    }
                }
                if (doc.detachedBaseline) validate(doc.detachedBaseline)
                catalog = doc; error = ""
            } else {
                const doc = Profiles.empty()
                doc.activeId = Profiles.add(doc, "Reloj actual", settings.snapshot())
                commit(doc)
            }
        } catch(e) { fail(e) }
    }
    function profileName(id) { const p = catalog ? Profiles.find(catalog,id) : null; return p ? p.name : "Perfil no disponible" }
    function createProfile(name) {
        if (!ready) return ""
        try { controller.finishPendingInputs(); const doc=Profiles.clone(catalog); const id=Profiles.add(doc,name,settings.snapshot()); doc.activeId=id; commit(doc); return id } catch(e) { fail(e); return "" }
    }
    function renameProfile(id,name) {
        try { const doc=Profiles.clone(catalog), p=Profiles.find(doc,id); if(!p)throw new Error("El perfil ya no existe"); p.name=Profiles.validName(doc,name,id);commit(doc);return true } catch(e) { return fail(e) }
    }
    function duplicateProfile(id) {
        try { const doc=Profiles.clone(catalog),p=Profiles.find(doc,id);if(!p)throw new Error("El perfil ya no existe");const added=Profiles.add(doc,Profiles.uniqueName(doc,p.name+" (copia)"),p.snapshot);commit(doc);return added } catch(e) {fail(e);return ""}
    }
    function load(id) {
        try { const doc=Profiles.clone(catalog),p=Profiles.find(doc,id);if(!p)throw new Error("El perfil ya no existe");validate(p.snapshot);settings.apply(p.snapshot);doc.activeId=id;commit(doc);pendingChange=null;return true } catch(e) {return fail(e)}
    }
    function activateProfile(id) { return id===activeId || requestLoad(id,"manual","") }
    function requestLoad(id,source,unused) {
        controller.finishPendingInputs()
        if(!ready || !Profiles.find(catalog,id))return false
        if(dirty){pendingChange={id:id,source:source};return false}
        return load(id)
    }
    function resolvePending(choice) {
        const request=pendingChange;if(!request)return
        if(choice==="save") {
            if(activeProfile){if(!saveProfile(activeId,true))return}
            else if(!createProfile(Profiles.uniqueName(catalog,"Reloj")))return
        }
        pendingChange=null
        if(choice!=="cancel")load(request.id)
    }
    function saveProfile(id,confirmed) {
        controller.finishPendingInputs()
        if(id!==activeId && !confirmed){pendingSave=id;return false}
        try {const doc=Profiles.clone(catalog),p=Profiles.find(doc,id);if(!p)throw new Error("El perfil ya no existe");p.snapshot=settings.snapshot();pendingSave="";commit(doc);return true} catch(e) {return fail(e)}
    }
    function confirmSave(confirmed) {const id=pendingSave;pendingSave="";if(confirmed)saveProfile(id,true)}
    function deleteBlockReason(id) {return !ready || !Profiles.find(catalog,id) ? "El perfil no está disponible" : count<2 ? "Crea otro perfil antes de eliminar el último" : ""}
    function canDeleteProfile(id) {return deleteBlockReason(id)===""}
    function requestDelete(id) {controller.finishPendingInputs();if(canDeleteProfile(id))pendingDelete=id}
    function confirmDelete(confirmed) {
        const id=pendingDelete;pendingDelete=""
        if(!confirmed || !canDeleteProfile(id))return
        try {
            const doc=Profiles.clone(catalog)
            if (id === activeId) doc.detachedBaseline = Profiles.clone(activeProfile.snapshot)
            Profiles.remove(doc,id)
            commit(doc)
            if (pendingChange?.id === id) pendingChange = null
            if (pendingSave === id) pendingSave = ""
            profileRemoved(id)
        } catch(e) {fail(e)}
    }
    // Settings finishes loading after component construction; never capture defaults early.
    Component.onCompleted: Qt.callLater(initialize)
}
