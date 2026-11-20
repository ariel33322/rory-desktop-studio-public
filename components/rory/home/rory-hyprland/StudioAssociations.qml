pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import "RoryTheme.js" as Theme
import "StudioProfiles.js" as Profiles
import "WallpaperIdentity.js" as Wallpaper

Item {
    id: root
    required property url storagePath
    visible:false; width:0; height:0
    required property var clockManager
    required property var audioManager
    required property var wallpaperSettings
    property var document:null
    property var pending:null
    property string error:""
    property var lastKey:null
    property bool applying:false
    readonly property bool ready:document!==null && clockManager.ready && audioManager.ready
    property var appliedRule: ({clockProfile:"",audioProfile:""})
    property var manualClock: null
    property var manualAudio: null
    readonly property bool clockVisible: manualClock ?? !!appliedRule.clockProfile
    readonly property bool audioVisible: manualAudio ?? !!appliedRule.audioProfile
    signal attentionRequired()
    Settings {
        id:saved
        location:root.storagePath
        category:"RoryStudioAssociations"
        property string data:""
    }
    function key(url) {return Wallpaper.normalize(url)}
    function ruleValid(rule) {
        if(!rule || typeof rule.clockProfile!=="string" || typeof rule.audioProfile!=="string")throw new Error("Asociación inválida")
        if (rule.appearance!==undefined) {
            if(!rule.appearance || typeof rule.appearance!=="object"
                || Object.keys(rule.appearance).some(key=>!["bar","center"].includes(key) || !Theme.valid(rule.appearance[key])))
                throw new Error("Tema vinculado inválido")
        }
        if (rule.taskbarProfile!==undefined && typeof rule.taskbarProfile!=="string") throw new Error("Perfil de barra inválido")
    }
    function validate(doc) {
        if(!doc || doc.version!==1 || !doc.entries || typeof doc.entries!=="object" || Array.isArray(doc.entries))throw new Error("Catálogo de asociaciones inválido")
        ruleValid(doc.defaults)
        for (const flag of ["clockDefaultEnabled","audioDefaultEnabled"])
            if (typeof doc.defaults[flag] !== "boolean") doc.defaults[flag] = false
        clockManager.validate(doc.clockFallback)
        audioManager.controller.validateSnapshot(doc.audioFallback)
        for(const url of Object.keys(doc.entries)){if(key(url)!==url)throw new Error("Ruta de asociación inválida");ruleValid(doc.entries[url])}
        return doc
    }
    function commit(doc) {validate(doc);saved.data=JSON.stringify(doc);document=doc;error=""}
    function initialize() {
        if(document || !clockManager.ready || !audioManager.ready)return
        try {
            if(saved.data)document=validate(JSON.parse(saved.data))
            else commit({version:1,entries:{},defaults:{clockProfile:"",audioProfile:"",clockDefaultEnabled:false,audioDefaultEnabled:false},clockFallback:clockManager.settings.snapshot(),audioFallback:audioManager.controller.snapshot()})
            clearMissingProfiles()
            Qt.callLater(handleWallpaperChange)
        }catch(e){error=String(e.message || e)}
    }
    function appearanceFor(url) {
        if(!document)return ({})
        try {return document.entries[key(url)]?.appearance ?? ({})}
        catch (_) {return ({})}
    }
    function setAppearance(url,component,theme) {
        try {
            if(!ready)throw new Error("Espera a que se carguen las asociaciones")
            const k=key(url)
            if(!k)throw new Error("Selecciona un fondo")
            if(!["bar","center"].includes(component) || (theme!=="" && !Theme.valid(theme)))throw new Error("Tema inválido")
            const doc=Profiles.clone(document)
            const entry=doc.entries[k] ?? {clockProfile:"",audioProfile:"",taskbarOnly:true}
            const appearance=Object.assign({},entry.appearance)
            if(theme)appearance[component]=theme
            else delete appearance[component]
            if(Object.keys(appearance).length)entry.appearance=appearance
            else delete entry.appearance
            if(entry.taskbarOnly && !entry.taskbarProfile && !entry.appearance)delete doc.entries[k]
            else doc.entries[k]=entry
            commit(doc)
            return true
        }catch(e){error=String(e.message || e);return false}
    }
    function taskbarProfile(url) {
        if (!document) return "global"
        try { return document.entries[key(url)]?.taskbarProfile || "global" }
        catch (_) { return "global" }
    }
    function setTaskbarProfile(url,id) {
        try {
            if (!ready) throw new Error("Espera a que se carguen las asociaciones")
            const k=key(url)
            if (!k && id==="global") return true
            if (!k) throw new Error("Selecciona un fondo para vincular un perfil")
            const doc=Profiles.clone(document)
            const entry=doc.entries[k] ?? {clockProfile:"",audioProfile:"",taskbarOnly:true}
            if (id==="global") {
                delete entry.taskbarProfile
                if (entry.taskbarOnly && !entry.appearance) delete doc.entries[k]
                else doc.entries[k]=entry
            } else {
                entry.taskbarProfile=id
                doc.entries[k]=entry
            }
            commit(doc)
            return true
        } catch(e) { error=String(e.message || e); return false }
    }
    function associationRule(url) {
        const k = key(url)
        const entry=document.entries[k]
        if (entry && !entry.taskbarOnly) return Profiles.clone(entry)
        const rule={clockProfile:"",audioProfile:audioManager.catalog.wallpapers[k] || ""}
        if (entry?.taskbarProfile) rule.taskbarProfile=entry.taskbarProfile
        return rule
    }
    function resolvedRule(url) {
        const explicit = associationRule(url), defaults = document.defaults
        return {
            clockProfile: explicit.clockProfile || (defaults.clockDefaultEnabled ? defaults.clockProfile : ""),
            audioProfile: explicit.audioProfile || (defaults.audioDefaultEnabled ? defaults.audioProfile : "")
        }
    }
    function setClockVisibility(visible) { manualClock = visible }
    function setAudioVisibility(visible) { manualAudio = visible }
    function allKeys() {
        if(!ready)return []
        return Array.from(new Set(Object.keys(document.entries).filter(k=>!document.entries[k].taskbarOnly).concat(Object.keys(audioManager.catalog.wallpapers)))).sort()
    }
    function saveAssociation(url,rule) {
        try {
            if(!ready)throw new Error("Los perfiles aún no están listos")
            ruleValid(rule);checkProfiles(rule)
            const k=key(url);if(!k)throw new Error("Selecciona un fondo")
            const doc=Profiles.clone(document);doc.entries[k]=Object.assign({},doc.entries[k],rule);delete doc.entries[k].taskbarOnly;commit(doc)
            return true
        }catch(e){error=String(e.message || e);return false}
    }
    function removeAssociation(url) {
        try {
            const k=key(url),doc=Profiles.clone(document)
            const legacy=audioManager.catalog.wallpapers[k]
            if(legacy && !audioManager.unlinkWallpaper(legacy,k))throw new Error(audioManager.error)
            if (doc.entries[k]?.taskbarProfile || doc.entries[k]?.appearance)
                doc.entries[k]=Object.assign({},doc.entries[k],{clockProfile:"",audioProfile:"",taskbarOnly:true})
            else delete doc.entries[k]
            commit(doc)
            return true
        }catch(e){error=String(e.message || e);return false}
    }
    function checkProfiles(rule) {
        if(rule.clockProfile && !Profiles.find(clockManager.catalog,rule.clockProfile))throw new Error("El perfil del reloj ya no existe; modifica la asociación")
        if(rule.audioProfile && !Profiles.find(audioManager.catalog,rule.audioProfile))throw new Error("El perfil del visualizador ya no existe; modifica la asociación")
    }
    function saveDefaults(rule,capture) {
        try {
            ruleValid(rule);checkProfiles(rule)
            const before = resolvedRule(wallpaperSettings.activeWallpaper)
            const doc=Profiles.clone(document);doc.defaults=Object.assign({},doc.defaults,rule)
            if(capture){clockManager.controller.finishPendingInputs();audioManager.controller.finishPendingInputs();doc.clockFallback=clockManager.settings.snapshot();doc.audioFallback=audioManager.controller.snapshot()}
            commit(doc)
            if (Profiles.signature(before) !== Profiles.signature(resolvedRule(wallpaperSettings.activeWallpaper)))
                requestWallpaper(wallpaperSettings.activeWallpaper,true)
            return true
        }catch(e){error=String(e.message || e);return false}
    }
    function clearMissingProfiles() {
        if (!ready) return
        const doc = Profiles.clone(document)
        let changed = false
        for (const rule of [doc.defaults, ...Object.values(doc.entries)]) {
            for (const [field, manager] of [["clockProfile", clockManager], ["audioProfile", audioManager]]) {
                if (rule[field] && !Profiles.find(manager.catalog, rule[field])) {
                    rule[field] = ""
                    if (rule === doc.defaults)
                        rule[field === "clockProfile" ? "clockDefaultEnabled" : "audioDefaultEnabled"] = false
                    changed = true
                }
            }
        }
        if (changed) commit(doc)
    }
    function profileRemoved(id, widget) {
        clearMissingProfiles()
        if (appliedRule[widget] !== id) return
        appliedRule = Object.assign({}, appliedRule, {[widget]:""})
        requestWallpaper(wallpaperSettings.activeWallpaper,true)
    }
    function plan(url) {
        clearMissingProfiles()
        const k = key(url), rule = resolvedRule(url)
        const changeClock = !!rule.clockProfile && clockManager.activeId !== rule.clockProfile
        const changeAudio = !!rule.audioProfile && audioManager.activeId !== rule.audioProfile
        const targetAudio = changeAudio
            ? audioManager.normalized(Profiles.find(audioManager.catalog,rule.audioProfile).snapshot) : null
        const audioSignature = changeAudio ? audioManager.fingerprint(audioManager.controller.snapshot()) : ""
        const audioBaseline = changeAudio && !audioManager.activeId
            && audioSignature === audioManager.fingerprint(document.audioFallback)
        const clockConflict = changeClock && clockManager.dirty
            && Profiles.signature(clockManager.settings.snapshot())
                !== Profiles.signature(Profiles.find(clockManager.catalog,rule.clockProfile).snapshot)
        const audioConflict = changeAudio && audioManager.dirty && !audioBaseline
            && audioSignature !== audioManager.fingerprint(targetAudio)
        return {key:k, rule:rule, changeClock:changeClock, changeAudio:changeAudio,
            clockConflict:clockConflict, audioConflict:audioConflict}
    }
    function finishInputs() {
        clockManager.controller.endTransaction()
        audioManager.controller.finishPendingInputs()
        audioManager.controller.endTransaction()
    }
    function setComposition(key, rule) {
        if (key !== lastKey) {
            manualClock=null
            manualAudio=null
            clockManager.settings.pointerEditMode=false
            wallpaperSettings.visualizerPointerEditMode=false
        }
        lastKey=key
        appliedRule=rule
    }
    function requestWallpaper(url,external) {
        if(!ready){error="Espera a que se carguen los perfiles";return false}
        try {
            pending=null
            finishInputs()
            const next = plan(url)
            const externalChange = external && lastKey !== null && next.key !== lastKey
            const request = {url:String(url),external:!!external,externalChange:externalChange,rule:next.rule,
                clockConflict:next.clockConflict,audioConflict:next.audioConflict}
            if (next.clockConflict || next.audioConflict) {
                if (externalChange) {
                    setComposition(next.key, {
                        clockProfile:next.changeClock ? "" : next.rule.clockProfile,
                        audioProfile:next.changeAudio ? "" : next.rule.audioProfile
                    })
                }
                pending=request
                error="";attentionRequired();return false
            }
            return applyRequest(request)
        }catch(e){error=String(e.message || e);attentionRequired();return false}
    }
    function applyRequest(request) {
        let beforeClock=null,beforeAudio=null,beforeClockCatalog=null,beforeAudioCatalog=null
        let oldUndo=null,oldRedo=null
        const beforeSelected=audioManager.selectedId
        try {
            const next=plan(request.url)
            beforeClock=clockManager.settings.snapshot();beforeAudio=audioManager.controller.snapshot()
            beforeClockCatalog=Profiles.clone(clockManager.catalog);beforeAudioCatalog=Profiles.clone(audioManager.catalog)
            oldUndo=audioManager.controller.undoStack.slice();oldRedo=audioManager.controller.redoStack.slice()
            applying=true
            if(next.changeClock) {
                if(!clockManager.load(next.rule.clockProfile))throw new Error(clockManager.error)
            }
            if (next.changeAudio && !audioManager.performLoad(next.rule.audioProfile))
                throw new Error(audioManager.error)
            if (!request.external) wallpaperSettings.imageUrl=request.url
            setComposition(next.key,next.rule)
            pending=null;error="";return true
        }catch(e){
            if(beforeClock){
                clockManager.settings.apply(beforeClock);clockManager.commit(beforeClockCatalog)
                audioManager.controller.applySnapshot(beforeAudio);audioManager.commit(beforeAudioCatalog)
                audioManager.controller.undoStack=oldUndo;audioManager.controller.redoStack=oldRedo
                audioManager.selectedId=beforeSelected
            }
            error=String(e.message || e);return false
        }finally{applying=false}
    }
    function resolve(choice) {
        if(!pending)return false
        if(choice==="cancel"){pending=null;error="";return true}
        if(clockManager.pendingChange || audioManager.pendingChange || clockManager.pendingDelete || audioManager.pendingDelete || clockManager.pendingSave || audioManager.pendingSave) {
            error="Resuelve primero las operaciones pendientes en los editores de perfiles.";return false
        }
        if(choice!=="copy" && choice!=="discard")return false
        const request=pending
        try {
            finishInputs()
            const next = plan(request.url)
            if (Profiles.signature(next.rule) !== Profiles.signature(request.rule))
                throw new Error("La asociación cambió. Vuelve a solicitar el cambio de fondo.")
            if (choice === "copy") {
                if (next.clockConflict && clockManager.count >= 20 || next.audioConflict && audioManager.count >= 20)
                    throw new Error("Libera un espacio de perfil para guardar los borradores")
                if (next.clockConflict && !clockManager.createProfile(Profiles.uniqueName(clockManager.catalog,"Borrador del reloj")))
                    throw new Error(clockManager.error)
                if (next.audioConflict && !audioManager.createProfile(Profiles.uniqueName(audioManager.catalog,"Borrador del visualizador")))
                    throw new Error(audioManager.error)
            }
            return applyRequest(request)
        }catch(e){error=String(e.message || e);return false}
    }
    function handleWallpaperChange() {
        if(!ready || applying || (wallpaperSettings.externalWallpaper && !wallpaperSettings.activeWallpaper && lastKey === null))return
        try {
            const k=key(wallpaperSettings.activeWallpaper)
            if(k===lastKey)return
            requestWallpaper(wallpaperSettings.activeWallpaper,true)
        }catch(e){error=String(e.message || e)}
    }
    Connections {target:root.wallpaperSettings;function onActiveWallpaperChanged(){Qt.callLater(root.handleWallpaperChange)}}
    Connections {
        target:root.clockManager
        function onReadyChanged(){Qt.callLater(root.initialize)}
        function onProfileRemoved(id){root.profileRemoved(id,"clockProfile")}
    }
    Connections {
        target:root.audioManager
        function onReadyChanged(){Qt.callLater(root.initialize)}
        function onProfileRemoved(id){root.profileRemoved(id,"audioProfile")}
    }
    Component.onCompleted:Qt.callLater(initialize)
}
