import QtQuick
import Quickshell
import "StudioProfiles.js" as Profiles

ShellRoot {
    id:tests
    function verify(value,message) {if(!value)throw new Error(message || "verify failed")}
    function compare(actual,expected) {if(actual!==expected)throw new Error("Expected "+JSON.stringify(expected)+", got "+JSON.stringify(actual))}
    function tryCompare(object,key,expected,timeout) {compare(object[key],expected)}
    Timer {
        interval:30;running:true;repeat:true
        property int attempts:0
        onTriggered:{
            if(!links.ready && attempts++<100)return
            stop()
            try {
                if(Quickshell.env("RORY_STUDIO_TEST")==="test_restart")tests.test_restart()
                else tests.test_associations()
                console.log("STUDIO_TEST_PASS")
            }catch(e){console.error("STUDIO_TEST_FAIL: "+e.message+"\n"+e.stack)}
            Qt.quit()
        }
    }
    ClockSettings {id:clock;storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")}
    ClockProfileManager {id:clocks;settings:clock}
    DeckWallpaperObserver {id:deck;endpoint:"";referenceOutput:"DP-1"}
    WallpaperSettings {id:wallpaper;profileManager:audio;studioVisibility:links.audioVisible;observedWallpaper:deck.path}
    VisualizerHistory {id:history;settings:wallpaper}
    StudioProfileManager {id:audio;controller:history;settings:wallpaper;associationManager:links}
    StudioAssociations {id:links;storagePath:"file://"+Quickshell.shellPath(".studio-associations.ini");clockManager:clocks;audioManager:audio;wallpaperSettings:wallpaper}
    StudioController {id:studio;storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini");clockSettings:clock;wallpaperSettings:wallpaper;clockManager:clocks;audioManager:audio;screens:[{name:"test"}]}
    function compileUi() {
        for(const path of ["StudioLauncher.qml","ClockEditor.qml","VisualizerEditor.qml","ClockBackground.qml","ClockBackgroundPanel.qml","StudioAssociationsPanel.qml"]) {
            const component=Qt.createComponent(Qt.resolvedUrl(path))
            if(component.status!==Component.Ready && component.errorString().includes("No PanelWindow backend loaded.")) {
                console.warn("SKIP native surface "+path+": offscreen has no PanelWindow backend")
                continue
            }
            verify(component.status===Component.Ready,path+": "+component.errorString())
        }
    }
    function waitReady(){tryCompare(links,"ready",true,5000);compare(links.error,"");verify(wallpaper.visualizerTestMode)}
    function rule(c,a,cv,av){return {clockProfile:c,audioProfile:a,clockVisible:cv,audioVisible:av}}
    function visibility(clockVisible,audioVisible) {
        compare(links.clockVisible,clockVisible)
        compare(links.audioVisible,audioVisible)
        compare(wallpaper.effectiveVisualizerEnabled,audioVisible)
    }
    function test_associations() {
        waitReady()
        compileUi()
        visibility(false,false)
        const baseClock=clock.snapshot()
        const audioA=audio.createProfile("Audio A")
        verify(audioA!=="",audio.error)
        const clockA=clocks.activeId
        clock.backgroundImage="file:///tmp/example.webp"
        clock.backgroundX=-45;clock.backgroundY=30
        clock.backgroundWidth=720;clock.backgroundHeight=410
        clock.backgroundScale=1.5;clock.backgroundRotation=42;clock.backgroundFit="contain"
        clock.backgroundEnabled=true
        compare(clock.timeSize,baseClock.timeSize)
        compare(clock.leftPercent,baseClock.leftPercent)
        compare(clock.horizontalAlignment,baseClock.horizontalAlignment)
        const clockB=clocks.createProfile("Reloj B")
        history.setValue("visualizerCenterX",850)
        verify(!wallpaper.visualizerHideSilentBars)
        history.setValue("visualizerHideSilentBars",true)
        history.setValue("visualizerSilenceThreshold",1.2)
        history.setValue("visualizerSilenceHold",1200)
        history.setValue("visualizerSilenceFade",350)
        const audioB=audio.createProfile("Audio B")
        verify(audioB!=="",audio.error)
        const catalogClock=Profiles.signature(clocks.catalog.profiles)
        const olderCatalog=Profiles.clone(audio.catalog)
        const olderProfile=Profiles.find(olderCatalog,audioA)
        for (const key of Object.keys(wallpaper.silenceDefaults)) delete olderProfile.snapshot[key]
        audio.commit(olderCatalog)
        const catalogAudio=Profiles.signature(audio.catalog.profiles)
        verify(!audio.dirty)
        verify(links.saveAssociation("/tmp/wall A.png",rule(clockA,audioA,false,false)),links.error)
        verify(links.saveAssociation("file:///tmp/wall%20B.png",rule(clockB,audioB,true,true)),links.error)
        compare(links.key("/tmp/wall A.png"),"file:///tmp/wall%20A.png")
        verify(links.requestWallpaper("/tmp/wall A.png",false),links.error)
        compare(clocks.activeId,clockA);compare(audio.activeId,audioA)
        verify(!wallpaper.visualizerHideSilentBars)
        compare(wallpaper.visualizerSilenceHold,600)
        verify(!audio.dirty)
        visibility(true,true)
        verify(links.requestWallpaper("/tmp/wall B.png",false),links.error)
        compare(clocks.activeId,clockB);compare(audio.activeId,audioB)
        verify(wallpaper.visualizerHideSilentBars)
        compare(wallpaper.visualizerSilenceThreshold,1.2)
        compare(wallpaper.visualizerSilenceHold,1200)
        compare(wallpaper.visualizerSilenceFade,350)
        compare(clock.backgroundWidth,720);compare(clock.backgroundRotation,42)
        compare(links.clockVisible,true);compare(links.audioVisible,true)
        clock.pointerEditMode=true
        history.beginTransaction()
        verify(links.requestWallpaper("/tmp/wall A.png",false), "idle pointer and transactions are not drafts")
        verify(links.requestWallpaper("/tmp/wall B.png",false), links.error)
        clock.pointerEditMode=false
        compare(Profiles.signature(clocks.catalog.profiles),catalogClock)
        compare(Profiles.signature(audio.catalog.profiles),catalogAudio)
        clock.timeSize=101
        history.setValue("visualizerCenterX",880)
        const beforeUrl=wallpaper.imageUrl
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        verify(links.pending.clockConflict && links.pending.audioConflict)
        compare(wallpaper.imageUrl,beforeUrl)
        compare(clock.timeSize,101);compare(wallpaper.visualizerCenterX,880)
        verify(links.resolve("cancel"))
        compare(clock.timeSize,101)
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        const clockCount=clocks.count,audioCount=audio.count
        verify(links.resolve("copy"),links.error)
        compare(clocks.count,clockCount+1);compare(audio.count,audioCount+1)
        compare(clocks.activeId,clockA);compare(audio.activeId,audioA)
        compare(Profiles.find(clocks.catalog,clockB).snapshot.timeSize,baseClock.timeSize)
        compare(Profiles.find(audio.catalog,audioB).snapshot.visualizerCenterX,850)
        // A direct imageUrl change also applies both profiles through the watcher.
        wallpaper.imageUrl="file:///tmp/wall%20B.png"
        links.handleWallpaperChange()
        tryCompare(clocks,"activeId",clockB)
        compare(audio.activeId,audioB)
        // Unlinked wallpaper preserves the clock's configuration, active profile, and background image.
        verify(links.requestWallpaper("/tmp/plain.png",false),links.error)
        compare(clock.backgroundImage,"file:///tmp/example.webp")
        compare(clocks.activeId,clockB)
        compare(clock.backgroundWidth,720)
        compare(clock.backgroundRotation,42)
        compare(wallpaper.visualizerCenterX,850)
        visibility(false,false)
        verify(links.requestWallpaper("/tmp/wall B.png",false),links.error)
        compare(clock.backgroundImage,"file:///tmp/example.webp")
        clock.timeSize=111
        history.setValue("visualizerCenterX",900)
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        verify(links.requestWallpaper("/tmp/latest.png",false))
        compare(links.pending,null)
        visibility(false,false)
        compare(wallpaper.visualizerCenterX,900)
        compare(clock.timeSize,111)
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        verify(links.resolve("discard"),links.error)
        compare(clocks.activeId,clockA)
        compare(clock.timeSize,baseClock.timeSize)
        verify(links.requestWallpaper("/tmp/wall B.png",false),links.error)
        // A changed association invalidates its pending confirmation.
        clock.timeSize=112
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        verify(links.saveAssociation("/tmp/wall A.png",rule(clockA,"",true,false)))
        verify(!links.resolve("discard"))
        compare(clock.timeSize,112)
        links.resolve("cancel")
        verify(!links.requestWallpaper("/tmp/wall A.png",false))
        verify(links.resolve("discard"),links.error)
        verify(links.requestWallpaper("/tmp/wall B.png",false),links.error)
        clock.timeSize=113
        links.setClockVisibility(true)
        wallpaper.setVisualizerVisibility(true)
        wallpaper.imageUrl="file:///tmp/wall%20A.png"
        links.handleWallpaperChange()
        verify(links.pending.externalChange && links.pending.clockConflict)
        visibility(false,false)
        verify(links.resolve("cancel"))
        compare(clock.timeSize,113)
        verify(links.requestWallpaper("/tmp/wall B.png",false),links.error)
        verify(clocks.load(clockB),clocks.error)
        // Feed Deck snapshots through the production observer without Wayland.
        const savedWallpaper = wallpaper.imageUrl
        function snapshot(path) {
            deck.snapshot = 99
            deck.receive(JSON.stringify({id: 99, result: {outputs: [
                {name: "DP-2", connected: true, path: "/tmp/ignored.png"},
                {name: "DP-1", connected: true, path: path}
            ]}}))
        }
        snapshot("/tmp/wall B.png")
        wallpaper.externalWallpaper = true
        links.handleWallpaperChange()
        clock.timeSize = 114
        snapshot("/tmp/wall A.png")
        links.handleWallpaperChange()
        verify(links.pending.externalChange && links.pending.clockConflict)
        verify(links.resolve("cancel"))
        compare(clock.timeSize,114)
        snapshot("/tmp/wall A.png")
        links.handleWallpaperChange()
        compare(links.pending,null)
        snapshot("/tmp/wall B.png")
        links.handleWallpaperChange()
        snapshot("/tmp/wall A.png")
        links.handleWallpaperChange()
        verify(links.resolve("discard"),links.error)
        compare(clocks.activeId,clockA)
        compare(wallpaper.imageUrl,savedWallpaper)
        wallpaper.externalWallpaper = false
        links.handleWallpaperChange()
        console.log("DECK_OBSERVER_TEST_PASS")
        // Removed target profiles stop automatic changes, preserving the current draft.
        verify(!links.saveAssociation("/tmp/bad.png",rule("missing",audioB,true,true)))
        // Legacy links retain identity and can be removed from the central panel.
        verify(audio.linkWallpaper(audioA,"/tmp/legacy.png",true))
        compare(links.associationRule("/tmp/legacy.png").audioProfile,audioA)
        verify(links.removeAssociation("/tmp/legacy.png"))
        verify(!audio.catalog.wallpapers["file:///tmp/legacy.png"])
        verify(links.saveAssociation("/tmp/clock-only.png",rule(clockA,"",false,true)))
        verify(links.saveAssociation("/tmp/audio-only.png",rule("",audioA,true,false)))
        verify(links.requestWallpaper("/tmp/clock-only.png",false),links.error)
        visibility(true,false)
        compare(clocks.activeId,clockA)
        verify(links.requestWallpaper("/tmp/audio-only.png",false),links.error)
        visibility(false,true)
        compare(audio.activeId,audioA)

        verify(links.requestWallpaper("/tmp/unlinked.png",false),links.error)
        visibility(false,false)
        const associations=Profiles.signature(links.document)
        const clockDraft=Profiles.signature(clock.snapshot())
        const audioDraft=audio.fingerprint(history.snapshot())
        links.setClockVisibility(true)
        wallpaper.setVisualizerVisibility(true)
        visibility(true,true)
        compare(Profiles.signature(links.document),associations)
        compare(Profiles.signature(clock.snapshot()),clockDraft)
        compare(audio.fingerprint(history.snapshot()),audioDraft)
        verify(links.requestWallpaper("/tmp/unlinked-other.png",false),links.error)
        visibility(false,false)

        const oldDocument=Profiles.clone(links.document)
        oldDocument.defaults=rule(clockB,audioB,true,true)
        const migrated=links.validate(oldDocument)
        compare(migrated.defaults.clockDefaultEnabled,false)
        compare(migrated.defaults.audioDefaultEnabled,false)
        compare(migrated.defaults.clockProfile,clockB)
        compare(migrated.defaults.audioProfile,audioB)
        verify(links.saveDefaults({clockProfile:clockB,audioProfile:audioB,clockDefaultEnabled:true,audioDefaultEnabled:false},false))
        visibility(true,false)
        compare(clocks.activeId,clockB)
        verify(links.saveDefaults({clockProfile:clockB,audioProfile:audioB,clockDefaultEnabled:false,audioDefaultEnabled:true},false))
        visibility(false,true)
        compare(audio.activeId,audioB)
        verify(links.saveDefaults({clockProfile:clockB,audioProfile:audioB,clockDefaultEnabled:true,audioDefaultEnabled:true},false))
        visibility(true,true)
        verify(links.requestWallpaper("/tmp/clock-only.png",false),links.error)
        visibility(true,true)
        compare(clocks.activeId,clockA)
        compare(audio.activeId,audioB)
        verify(links.requestWallpaper("/tmp/audio-only.png",false),links.error)
        visibility(true,true)
        compare(clocks.activeId,clockB)
        compare(audio.activeId,audioA)
        links.setClockVisibility(false)
        wallpaper.setVisualizerVisibility(false)
        visibility(false,false)
        verify(links.requestWallpaper("/tmp/unlinked.png",false),links.error)
        visibility(true,true)
        compare(clocks.activeId,clockB)
        compare(audio.activeId,audioB)
        verify(links.removeAssociation("/tmp/wall A.png"))
        verify(!links.document.entries["file:///tmp/wall%20A.png"])
        // One shared navigation state, preserving all profile data.
        studio.home(null);compare(studio.page,"home")
        studio.open("clock",null);compare(studio.page,"");verify(clock.editorOpen)
        studio.open("audio",null);verify(!clock.editorOpen);verify(wallpaper.visualizerEditorOpen)
        studio.open("wallpapers",null);verify(!wallpaper.visualizerEditorOpen);compare(studio.page,"wallpapers")
        studio.home(null);studio.toggle();compare(studio.page,"")
        verify(links.saveAssociation("/tmp/deleted-audio.png",rule(clockB,audioA,true,true)))
        verify(audio.requestDelete(audioA))
        verify(audio.confirmDelete(true))
        compare(links.associationRule("/tmp/deleted-audio.png").audioProfile,"")
        compare(links.associationRule("/tmp/deleted-audio.png").clockProfile,clockB)
        studio.centralShortcut=true
        verify(clocks.saveProfile(clockB,false))
        links.setClockVisibility(false)
        wallpaper.setVisualizerVisibility(false)
        visibility(false,false)
    }
    function test_restart() {
        waitReady()
        verify(studio.centralShortcut)
        compare(clock.backgroundImage,"file:///tmp/example.webp")
        compare(clock.backgroundWidth,720)
        compare(clock.backgroundHeight,410)
        compare(clock.backgroundScale,1.5)
        compare(clock.backgroundRotation,42)
        compare(clock.backgroundFit,"contain")
        compare(clock.backgroundX,-45)
        const entry=links.document.entries["file:///tmp/wall%20B.png"]
        verify(!!entry)
        compare(clocks.profileName(entry.clockProfile),"Reloj B")
        compare(clocks.activeId,entry.clockProfile)
        compare(audio.profileName(entry.audioProfile),"Audio B")
        verify(wallpaper.visualizerHideSilentBars)
        compare(wallpaper.visualizerSilenceThreshold,1.2)
        compare(wallpaper.visualizerSilenceHold,1200)
        compare(wallpaper.visualizerSilenceFade,350)
        verify(links.document.defaults.clockDefaultEnabled && links.document.defaults.audioDefaultEnabled)
        compare(links.document.defaults.clockProfile,entry.clockProfile)
        compare(links.document.defaults.audioProfile,entry.audioProfile)
        visibility(true,true)
        // Old clock snapshots gain only the new fields, preserving existing data.
        const legacy=Profiles.clone(clock.snapshot())
        for(const key of ["backgroundImage","backgroundX","backgroundY","backgroundWidth","backgroundHeight","backgroundScale","backgroundRotation","backgroundFit"])delete legacy[key]
        legacy.timeSize=117
        clocks.validate(legacy)
        compare(legacy.backgroundImage,"");compare(legacy.backgroundScale,1)
        compare(legacy.timeSize,117)
        // V1.0.0 clock snapshots missing all 22 added fields gain defaults gracefully.
        const v1Snapshot={timeSize:117,accent:"#a21032",textColor:"#f3eef0",title:"ロウリィ",signature:"RORY",widgetOpacity:0.95,leftPercent:0.15,topPercent:0.25,use24Hour:true}
        clocks.validate(v1Snapshot)
        compare(v1Snapshot.backgroundImage,"")
        compare(v1Snapshot.backgroundScale,1)
        compare(v1Snapshot.customWidth,0)
        compare(v1Snapshot.fontFamily,"Noto Sans")
        compare(v1Snapshot.timeSize,117)
    }
}
