import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "GeometryEngine.js" as Geometry
import "StudioProfiles.js" as Profiles
import "Representation.js" as Styles
import "PathCuts.js" as Cuts

ShellRoot {
    id:tests
    readonly property string linkedUrl:"file://"+Quickshell.shellPath("wallpapers/linked.png")
    property int stage:0
    property var failures:[]
    function verify(value,message){if(!value)throw new Error(message || "verify failed")}
    function compare(actual,expected,message){if(actual!==expected)throw new Error((message || "compare")+": expected "+JSON.stringify(expected)+", got "+JSON.stringify(actual))}
    function descendants(root){let items=[root];for(const child of (root.children || []))items=items.concat(descendants(child));return items}
    function named(root,name){const item=descendants(root).find(item=>item.objectName===name);verify(!!item,"Missing UI control: "+name);return item}
    function expand(root){for(const item of descendants(root))if(item.expanded!==undefined && item.title!==undefined)item.expanded=true}
    function visibleControl(root,name){const item=named(root,name);verify(item.visible && item.enabled,"Inaccessible UI control: "+name);return item}
    ClockSettings {id:clock;storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")}
    ClockProfileManager {id:clocks;settings:clock}
    WallpaperSettings {id:wallpaper;profileManager:audio;studioController:studio;studioVisibility:links.audioVisible}
    VisualizerHistory {id:history;settings:wallpaper}
    StudioProfileManager {id:audio;controller:history;settings:wallpaper;associationManager:links}
    StudioAssociations {id:links;storagePath:"file://"+Quickshell.shellPath(".studio-associations.ini");clockManager:clocks;audioManager:audio;wallpaperSettings:wallpaper}
    StudioController {id:studio;storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini");clockSettings:clock;wallpaperSettings:wallpaper;clockManager:clocks;audioManager:audio;screens:Quickshell.screens}
    WindowCoverage { id: coverage; monitoring:false }
    Variants {
        id: desktopClocks
        reloadableId: "desktopClocks"
        model: Quickshell.screens
        ClockWidget {settings:clock;windowCoverage:coverage;displayEnabled:links.clockVisible}
    }
    Window {
        id:host;visible:true;width:900;height:900
        RoryAudioVisualizer {id:visualizer;settings:wallpaper;windowCoverage:coverage;monitorName:""}
        ScrollView {
            id:hostScroll
            anchors.fill:parent;contentWidth:availableWidth
            ColumnLayout {
                width:hostScroll.availableWidth
                StudioNavigation {id:menu;Layout.fillWidth:true;studio:studio;targetScreen:Quickshell.screens[0];destination:studio.page || (clock.editorOpen ? "clock" : "audio")}
                StudioProfileBar {id:audioBar;Layout.fillWidth:true;manager:audio}
                AudioLayersPanel {id:layers;Layout.fillWidth:true;controller:history;settings:wallpaper}
                StudioAudioPanel {id:globalAudio;Layout.fillWidth:true;controller:history;settings:wallpaper}
                StudioProfileBar {id:clockBar;Layout.fillWidth:true;manager:clocks}
                StudioWallpaperWorkspace {id:workspace;Layout.fillWidth:true;settings:wallpaper;manager:links}
            }
        }
    }
    Timer {
        interval:150;repeat:true;running:true
        property int attempts:0
        onTriggered:{
            if(!links.ready && attempts++<30)return
            try {
                verify(links.ready,links.error || audio.error || clocks.error)
                if(Quickshell.env("RORY_REGRESSION_PHASE")==="restart"){tests.restart();stop();console.log("REGRESSION_TEST_PASS restart");Qt.quit();return}
                if(stage===0){tests.prepare();stage++;return}
                if(stage===1){tests.bars();stage++;return}
                if(stage===2){tests.sharedGeometry();stage++;return}
                if(stage===3){tests.waves();stage++;return}
                if(stage===4){tests.particles();stage++;return}
                if(stage===5){tests.profilesAndWallpapers();stage++;return}
                if(stage===6){
                    const gallery=descendants(workspace).find(item=>typeof item.choose==="function")
                    if(gallery && !gallery.gallery.some(path=>gallery.localUrl(path)===linkedUrl) && attempts++<30)return
                    tests.compact();stop();console.log("REGRESSION_TEST_PASS exercise");Qt.quit()}
            }catch(e){console.error("REGRESSION_TEST_FAIL: "+e.message+"\n"+e.stack);stop();Qt.quit()}
        }
    }
    function prepare(){
        verify(audio.createProfile("Regresión audio")!=="",audio.error)
        expand(layers)
    }
    function bars(){
        for(const key of ["common_x","common_y","common_scale","common_rotation","common_normalOffset","common_opacity","representationStyle","geometrySource","layerColor","bars_density","bars_length","bars_thickness","bars_gap","bars_intensity","bars_sensitivity","bars_temporal","bars_glow","bars_glowIntensity","bars_glowSensitivity","bars_glowSmoothing","animationType","animation_speed","animation_intensity","animation_sensitivity","animation_smoothing","cutStart","cutLength","hideRange","restoreRange","addLayer","selectSharedGeometry"])visibleControl(layers,key)
        const count=visibleControl(layers,"visualizerBarCount")
        compare(count.label,"Número de barras")
        const field=named(count,"numericValue")
        field.forceActiveFocus();field.text="240";field.textEdited();field.editingFinished()
        compare(wallpaper.visualizerBarCount,240,"bar count UI → settings")
        compare(history.snapshot().visualizerBarCount,240)
        // Verify actual controls dispatch per-layer edits without changing another layer.
        visibleControl(layers,"addLayer").clicked()
        const other=layers.currentId
        verify(other!=="main");layers.select("main");expand(layers)
        const before=Profiles.signature(history.document.layers.find(layer=>layer.id===other))
        visibleControl(layers,"bars_length").valueEdited(81)
        compare(history.document.layers.find(layer=>layer.id==="main").params.bars.length,81)
        compare(Profiles.signature(history.document.layers.find(layer=>layer.id===other)),before)
        visibleControl(layers,"common_x").valueEdited(35)
        compare(history.document.layers.find(layer=>layer.id==="main").common.x,35)
        const originalSharedWidth=wallpaper.visualizerWidth
        visibleControl(layers,"geometrySource").activated(1)
        visibleControl(layers,"local_visualizerWidth").valueEdited(680)
        compare(history.document.layers.find(layer=>layer.id==="main").geometry.custom.visualizerWidth,680)
        compare(wallpaper.visualizerWidth,originalSharedWidth,"own geometry must not overwrite shared geometry")
        visibleControl(layers,"geometrySource").activated(0)
        visibleControl(layers,"animationType").activated(2)
        visibleControl(layers,"animation_speed").valueEdited(2.4)
        compare(history.document.layers.find(layer=>layer.id==="main").animation.mode,"rotate")
        compare(history.document.layers.find(layer=>layer.id==="main").animation.speed,2.4)
        for(const key of ["global_visualizerSensitivity","global_visualizerBass","global_visualizerAttack","global_visualizerSmoothing","visualizerTestMode"])visibleControl(globalAudio,key)
        for(const entry of Styles.catalog().filter(entry=>entry.type==="bars")) {
            const selector=visibleControl(layers,"representationStyle")
            selector.activated(selector.model.findIndex(label=>label.endsWith(entry.label)))
            compare(history.document.layers.find(layer=>layer.id==="main").styles.bars,entry.id)
            const specifics={rounded:["bars_rounding"],segmented:["bars_segmentSize","bars_segmentGap"],peaks:["bars_peakDecay"]}
            for(const name of (specifics[entry.id] || []))visibleControl(layers,name)
        }
        deleteHiddenRange()
        named(layers,"selectSharedGeometry").clicked()
    }
    function deleteHiddenRange(){
        const selector=visibleControl(layers,"cutIntervalSelector")
        const remove=named(layers,"deleteHiddenRange")
        const start=visibleControl(layers,"cutStart")
        const end=visibleControl(layers,"cutEnd")
        const length=visibleControl(layers,"cutLength")
        const zoom=descendants(layers).find(item=>item.label==="Zoom de edición" && item.visible)
        verify(zoom && zoom.visible && zoom.enabled)
        zoom.valueEdited(2)
        const edit=(position,size,action)=>{
            selector.activated(0)
            start.valueEdited(position*start.to)
            length.valueEdited(size*length.to)
            visibleControl(layers,action).clicked()
        }
        edit(.875,.25,"hideRange")
        verify(remove.visible && remove.enabled)
        edit(.0625,.125,"hideRange")
        edit(.09375,.0625,"restoreRange")
        verify(!remove.visible,"visible interval must not show the direct delete action")
        selector.activated(1)
        compare(end.value,.125*end.to,"selected interval crosses the origin")
        const before=Profiles.clone(history.document)
        const cuts=before.layers.find(layer=>layer.id==="main").cuts
        const beforeMask=Cuts.mask(cuts,240)
        const removed=cuts.intervals[0]
        const expected=Profiles.clone(before)
        const expectedCuts=expected.layers.find(layer=>layer.id==="main").cuts
        expectedCuts.intervals.splice(0,1)
        remove.clicked()
        compare(selector.model.length,3,"the interval disappears immediately from the selector")
        compare(selector.currentIndex,0)
        compare(zoom.value,2)
        compare(Profiles.signature(history.document),Profiles.signature(expected),"only the selected interval is removed")
        const afterMask=Cuts.mask(expectedCuts,240)
        verify(afterMask.some((shown,index)=>shown && !beforeMask[index]))
        for(let index=0;index<afterMask.length;++index) {
            if(!Cuts.contains(removed,index/240))compare(afterMask[index],beforeMask[index],"bars outside the interval")
            if(beforeMask[index])verify(afterMask[index],"no previously visible bar disappears")
        }
        history.undo()
        compare(Profiles.signature(history.document),Profiles.signature(before))
        compare(selector.model.length,4)
        history.redo()
        compare(Profiles.signature(history.document),Profiles.signature(expected))
    }
    function sharedGeometry(){
        for(const key of ["localGeometry","local_visualizerWidth","local_visualizerHeight","local_visualizerRadiusX","local_visualizerRadiusY","local_visualizerOrientation","local_visualizerOffset","local_visualizerScale","vertexMode","editPoints"])visibleControl(layers,key)
        const width=visibleControl(layers,"local_visualizerWidth")
        width.valueEdited(620);compare(wallpaper.visualizerWidth,620)
        verify(descendants(layers).some(item=>item.label==="Centro X" && item.visible))
        verify(descendants(layers).some(item=>item.label==="Centro Y" && item.visible))
        const geometry=visibleControl(layers,"localGeometry")
        for(let index=0;index<6;index++) {
            geometry.activated(index)
            compare(wallpaper.visualizerGeometry,["circle","ellipse","square","triangle","star","wave"][index])
        }
        named(layers,"editPoints").clicked()
        for(const name of ["freeWavePanel","freeWaveMode","addWavePoint","deleteWavePoint"])visibleControl(layers,name)
        geometry.activated(1)
        layers.select("main");history.setLayerStyle("main","fluid");expand(layers)
    }
    function waves(){
        expand(layers)
        for(const key of ["waves_density","waves_spatial","waves_speed","waves_amplitude","waves_thickness","waves_intensity","waves_sensitivity","waves_temporal","waves_glow","waves_glowIntensity","waves_glowSensitivity","waves_glowSmoothing"])visibleControl(layers,key)
        visibleControl(layers,"waves_amplitude").valueEdited(64)
        compare(history.document.layers.find(layer=>layer.id==="main").params.waves.amplitude,64)
        for(const entry of Styles.catalog().filter(entry=>entry.type==="waves")) {
            const selector=visibleControl(layers,"representationStyle")
            selector.activated(selector.model.findIndex(label=>label.endsWith(entry.label)))
            compare(history.document.layers.find(layer=>layer.id==="main").styles.waves,entry.id)
            if(entry.id==="fluid")visibleControl(layers,"waves_fluidness")
            if(["fluid","spectral","spectrumLine"].indexOf(entry.id)>=0)visibleControl(layers,"waves_spatial")
        }
        history.setLayerType("main","particles");expand(layers)
    }
    function particles(){
        expand(layers)
        for(const key of ["particles_maximum","particles_size","particles_speed","particles_life","particles_dispersion","particles_intensity","particles_sensitivity","representationStyle"])visibleControl(layers,key)
        const inherit=descendants(layers).find(item=>item.text==="Usar el color de la principal" && typeof item.toggled==="function")
        verify(!!inherit);inherit.checked=false;inherit.toggled()
        const color=visibleControl(layers,"layerColor")
        color.forceActiveFocus();color.text="rgb(16,32,48)";color.textEdited();color.editingFinished()
        compare(history.document.layers.find(layer=>layer.id==="main").common.color,"#102030")
        const selector=visibleControl(layers,"representationStyle")
        for(const entry of ["Chispas","Polvo luminoso","Órbita"]) {
            const index=selector.model.findIndex(label=>label.endsWith(entry));verify(index>=0)
            selector.activated(index)
            compare(history.document.layers.find(layer=>layer.id==="main").params.particles.mode,["sparks","dust","orbit"][["Chispas","Polvo luminoso","Órbita"].indexOf(entry)])
        }
        history.setLayerType("main","bars");expand(layers)
    }
    function menuItem(bar,name){const item=bar.actionsMenu.contentData.find(item=>item.objectName===name);verify(!!item,"Missing profile menu action "+name);return item}
    function profilesAndWallpapers(){
        // Common profile actions are reachable from the context menu.
        for(const bar of [audioBar,clockBar]) {
            compare(descendants(bar).filter(item=>item.text==="Guardar" && typeof item.clicked==="function" && item.visible).length,0)
            compare(descendants(bar).filter(item=>item.objectName==="createProfile").length,0)
            const labels=bar.actionsMenu.contentData.filter(item=>item.text!==undefined).map(item=>item.text)
            for(const name of ["Guardar","Guardar como nuevo","Duplicar","Renombrar","Eliminar perfil","Revertir…"])compare(labels.filter(label=>label===name).length,1,name)
            for(const name of ["saveAsNewProfile","duplicateProfile","renameProfile","deleteProfile","revertProfile"])menuItem(bar,name)
        }
        wallpaper.setVisualizerVisibility(true)
        menuItem(audioBar,"saveManagedProfile").triggered()
        compare(audio.activeProfile.snapshot.visualizerBarCount,240)
        const beforeAudio=Profiles.signature(audio.catalog.profiles)
        clock.timeSize=98
        verify(Quickshell.screens.length > 0, "offscreen needs a virtual screen")
        const widgets = Array.from(desktopClocks.instances)
        compare(widgets.length,Quickshell.screens.length)
        verify(widgets.every(item=>!item.visible),"unlinked wallpaper hides every clock")
        links.setClockVisibility(true)
        verify(widgets.every(item=>item.visible),"manual activation shows one clock per screen")
        const initialClockCount=clocks.count
        verify(clock.timeSize !== clocks.activeProfile.snapshot.timeSize && clocks.dirty)
        for (let i=0;i<10;++i) menuItem(clockBar,"saveManagedProfile").triggered()
        compare(clocks.count,initialClockCount)
        verify(!clocks.dirty && !audio.dirty)
        const duplicate=clocks.duplicateProfile(clocks.activeId)
        verify(!!duplicate)
        verify(links.saveAssociation("/tmp/deleted-clock.png",{clockProfile:duplicate,audioProfile:audio.activeId,clockVisible:true,audioVisible:true}))
        clocks.requestDelete(duplicate)
        clocks.confirmDelete(true)
        compare(clocks.count,initialClockCount)
        compare(links.associationRule("/tmp/deleted-clock.png").clockProfile,"")
        compare(links.associationRule("/tmp/deleted-clock.png").audioProfile,audio.activeId)
        compare(desktopClocks.instances.length,widgets.length)
        verify(widgets.every(item=>desktopClocks.instances.includes(item) && item.visible),"clock objects survive save, duplication and deletion")
        compare(clocks.activeProfile.snapshot.timeSize,98)
        compare(Profiles.signature(audio.catalog.profiles),beforeAudio,"independent clock/audio profiles")
        // Saving a link changes only the association; choosing a wallpaper applies only saved data.
        workspace.page=2
        const form=descendants(workspace).find(item=>typeof item.edit==="function" && typeof item.rule==="function")
        verify(!!form,"association form accessible")
        form.edit(linkedUrl)
        compare(named(form,"clockDefaultEnabled").checked,false)
        compare(named(form,"audioDefaultEnabled").checked,false)
        for (const [picker,toggle] of [["clockProfileDefault","clockDefaultEnabled"],["audioProfileDefault","audioDefaultEnabled"]]) {
            visibleControl(form,picker).activated(1)
            const control=visibleControl(form,toggle)
            control.checked=true;control.toggled()
            compare(links.document.defaults[toggle],true)
            control.checked=false;control.toggled()
            compare(links.document.defaults[toggle],false)
        }
        named(form,"associationClockProfile").activated(1)
        named(form,"associationAudioProfile").activated(1)
        const previousWallpaper=wallpaper.imageUrl
        visibleControl(form,"saveWallpaperAssociation").clicked()
        compare(wallpaper.imageUrl,previousWallpaper,"link must not apply wallpaper")
        compare(links.document.entries[linkedUrl].clockProfile,clocks.activeId)
        compare(links.document.entries[linkedUrl].audioProfile,audio.activeId)
        verify(!descendants(form).some(item=>item.text==="Aplicar y cambiar fondo"),"no combined save/apply")
        visibleControl(form,"deleteWallpaperAssociation").clicked()
        verify(form.dialogs.removeUi.visible)
        form.dialogs.removeUi.reject()
        verify(!!links.document.entries[linkedUrl])
        visibleControl(form,"deleteWallpaperAssociation").clicked();form.dialogs.removeUi.accept()
        verify(!links.document.entries[linkedUrl])
        visibleControl(form,"saveWallpaperAssociation").clicked()
        named(workspace,"wallpaperConfigureTab").clicked()
        visibleControl(workspace,"wallpaperFitMode").activated(1)
        compare(wallpaper.fitMode,"fit")
        const dim=visibleControl(workspace,"wallpaperDim");dim.value=0.25;dim.moved()
        compare(wallpaper.dim,0.25)
        compare(wallpaper.imageUrl,previousWallpaper,"configuration must not apply wallpaper")
        studio.page="home"
        named(workspace,"wallpaperApplyTab").clicked()
        const gallery=descendants(workspace).find(item=>typeof item.choose==="function")
        verify(!!gallery,"apply gallery accessible")
        verify(gallery.choose(linkedUrl),links.error)
        compare(wallpaper.imageUrl,linkedUrl)
        compare(studio.page,"home","wallpaper must not open configuration")
        verify(!clock.editorOpen && !wallpaper.visualizerEditorOpen)
        compare(wallpaper.effectiveVisualizerEnabled,true)
        const visibility=visibleControl(globalAudio,"visualizerVisibility")
        compare(visibility.checked,true)
        visibility.checked=false;visibility.toggled()
        compare(wallpaper.effectiveVisualizerEnabled,false)
        visibility.checked=true;visibility.toggled()
        compare(wallpaper.effectiveVisualizerEnabled,true,"manual visibility must override wallpaper hiding")
        verify(!audio.dirty,"visibility override must not dirty an identical saved activation")
        // Unlinked wallpaper preserves clock edits without false conflict.
        clock.timeSize=104
        compare(gallery.choose("/tmp/unlinked-regression.png"),true)
        compare(wallpaper.imageUrl,"file:///tmp/unlinked-regression.png")
        compare(clock.timeSize,104,"clock customizations survive unlinked wallpaper change")
        compare(studio.page,"home","wallpaper change must not navigate")
        verify(widgets.every(item=>!item.visible))
        verify(!wallpaper.effectiveVisualizerEnabled)
        verify(!visualizer.visible)
        wallpaper.visualizerEditorOpen=true
        wallpaper.visualizerTestMode=false
        verify(!wallpaper.visualizerAudioActive,"hidden visualizer must not start audio with its editor open")
        verify(!visualizer.visible)
        wallpaper.visualizerTestMode=true
        wallpaper.visualizerEditorOpen=false
        for (let i=0;i<6;++i) {
            verify(gallery.choose(linkedUrl),links.error)
            verify(widgets.every(item=>item.visible && desktopClocks.instances.includes(item)))
            verify(visualizer.visible)
            verify(gallery.choose("/tmp/unlinked-regression.png"),links.error)
            verify(widgets.every(item=>!item.visible && desktopClocks.instances.includes(item)))
            verify(!visualizer.visible)
            compare(desktopClocks.instances.length,widgets.length)
        }
        // Switch back to linkedUrl
        verify(gallery.choose(linkedUrl))
        compare(wallpaper.imageUrl,linkedUrl)
        // Separate selection-only mode emits a file without applying it or saving a link.
        gallery.selectionOnly=true
        verify(gallery.choose("/tmp/selection-only.png"))
        compare(wallpaper.imageUrl,linkedUrl)
        verify(!links.document.entries["file:///tmp/selection-only.png"])
        clock.timeSize=98
        menuItem(clockBar,"renameProfile").triggered()
        verify(clockBar.renaming);clockBar.cancelName()
        clock.timeSize=109
        menuItem(clockBar,"revertProfile").triggered()
        verify(!!clocks.pendingChange)
        clocks.resolvePending("discard");compare(clock.timeSize,98)
        menuItem(clockBar,"saveAsNewProfile").triggered()
        clockBar.cancelName();compare(clocks.count,2)
        menuItem(clockBar,"deleteProfile").triggered()
        verify(clocks.pendingDelete!=="");compare(clocks.count,2)
        clocks.confirmDelete(false);compare(clocks.count,2)
        menuItem(audioBar,"duplicateProfile").triggered()
        compare(audio.count,2)
        // Exercise the values used by both pointer handlers and read them back
        // from the real numerical controls and persisted profiles.
        layers.selectShared()
        const beforeLayers=Profiles.signature(history.document.layers)
        history.beginTransaction()
        history.moveSharedGeometry(900,540,20,30,2)
        history.resizeSharedGeometry(600,500,100,80,2)
        history.endTransaction()
        compare(Profiles.signature(history.document.layers),beforeLayers)
        compare(visibleControl(layers,"local_visualizerWidth").value,650)
        compare(visibleControl(layers,"local_visualizerHeight").value,540)
        compare(wallpaper.visualizerCenterX,910)
        compare(wallpaper.visualizerCenterY,555)
        menuItem(audioBar,"saveManagedProfile").triggered()
        const pointer=descendants(widgets[0].contentItem).find(item=>typeof item.applySize==="function")
        verify(!!pointer,"clock pointer handler lives in the actual clock")
        pointer.applyPosition(100,100,50,60)
        compare(clock.leftPercent,150 / widgets[0].modelData.width)
        compare(clock.topPercent,160 / widgets[0].modelData.height)
        pointer.applySize(150,160,300,200,30,45,false,clock.timeSize)
        compare(clock.widgetWidth,330)
        compare(clock.widgetHeight,245)
        clock.editorScreen=widgets[0].modelData
        clock.enableFreeLayout()
        verify(clock.elementsLayout && clock.elementsLayout.length===5,"free layout initialized from the actual clock")
        const minutes=Profiles.signature(clock.elementsLayout[1])
        const seconds=Profiles.signature(clock.elementsLayout[2])
        clock.editElement(0,{x:11,y:37,size:54,family:"Serif",fill:"#123456",outline:"#abcdef",stroke:3})
        clock.showSeconds=true
        clock.showSeconds=false
        compare(Profiles.signature(clock.elementsLayout[1]),minutes)
        compare(Profiles.signature(clock.elementsLayout[2]),seconds)
        compare(clock.elementsLayout[0].x,11)
        clock.backgroundImage=linkedUrl
        clock.backgroundEnabled=true
        menuItem(clockBar,"saveManagedProfile").triggered()
        verify(!clocks.dirty && !audio.dirty)
        const updatedLink=links.associationRule(linkedUrl)
        updatedLink.clockProfile=clocks.activeId
        verify(links.saveAssociation(linkedUrl,updatedLink),links.error)
        const clockState=Profiles.signature(clock.snapshot()), audioState=audio.fingerprint(history.snapshot())
        for (const id of ["clock","audio","wallpapers","associations","home"]) {
            menu.activated(studio.destinations.findIndex(entry=>entry.id===id))
            if (id==="clock") verify(clock.editorOpen)
            else if (id==="audio") verify(wallpaper.visualizerEditorOpen)
            else compare(studio.page,id)
        }
        compare(Profiles.signature(clock.snapshot()),clockState)
        compare(audio.fingerprint(history.snapshot()),audioState)
        compare(form.editingUrl,linkedUrl)
        host.width=500
        layers.selectShared()
    }
    function compact(){
        visibleControl(layers,"visualizerBarCount")
        visibleControl(layers,"selectSharedGeometry")
        for(const key of ["localGeometry","local_visualizerWidth","local_visualizerHeight"])visibleControl(layers,key)
        verify(layers.width>0 && layers.width<=host.width,"compact panel must fit the window: panel="+layers.width+", window="+host.width)
        verify(named(layers,"visualizerBarCount").width>0)
        const gallery=descendants(workspace).find(item=>typeof item.choose==="function")
        verify(gallery.gallery.some(path=>gallery.localUrl(path)===linkedUrl),"gallery scanner must return the fixture image: "+gallery.wallpaperFolder+" / "+JSON.stringify(gallery.gallery))
        history.editLinear({length:320,height:60,count:48,x:30,y:70,inset:12})
        for(const edge of ["top","bottom","left","right"]){
            history.editLinear({edge:edge})
            const frame=Geometry.linearFrame(wallpaper.visualizerLinear,500,400)
            const points=Geometry.linearPoints(frame,48)
            compare(points.length,48)
            compare(frame.base,{top:12,bottom:388,left:12,right:488}[edge])
            compare(frame.reverse,edge==="bottom" || edge==="right")
            const smaller=Geometry.linearFrame(wallpaper.visualizerLinear,200,150)
            verify(smaller.length<=smaller.along)
        }
        const oldGeometry=wallpaper.visualizerGeometry
        history.setValue("visualizerEffect","linear")
        verify(wallpaper.spectrumEffect)
        history.undo()
        compare(wallpaper.visualizerEffect,"radial")
        compare(wallpaper.visualizerGeometry,oldGeometry)
        verify(audio.saveProfile(audio.activeId,false),audio.error)
        console.log("UI inventory: bars, geometry, position, representations, color, audio, glow, animations, cuts, particles, profiles; wide and compact layouts")
    }
    function restart(){
        compare(wallpaper.visualizerBarCount,240,"bar count persisted across process restart")
        compare(audio.activeProfile.snapshot.visualizerBarCount,240)
        const savedCuts=JSON.parse(audio.activeProfile.snapshot.visualizerLayersV2).layers.find(layer=>layer.id==="main").cuts
        const expectedCuts={baseVisible:true,intervals:[{start:.0625,length:.125,visible:false},{start:.09375,length:.0625,visible:true}]}
        compare(Profiles.signature(savedCuts),Profiles.signature(expectedCuts),"deletion persisted in the linked profile")
        compare(Profiles.signature(history.document.layers.find(layer=>layer.id==="main").cuts),Profiles.signature(expectedCuts))
        compare(clocks.activeProfile.snapshot.timeSize,98)
        compare(clock.backgroundImageUrl,linkedUrl)
        verify(clock.backgroundEnabled)
        compare(clock.widgetWidth,330)
        compare(clock.widgetHeight,245)
        compare(clock.elementsLayout[0].x,11)
        compare(clock.elementsLayout[0].y,37)
        compare(clock.elementsLayout[0].size,54)
        compare(clock.elementsLayout[0].family,"Serif")
        compare(clock.elementsLayout[0].fill,"#123456")
        compare(clock.elementsLayout[0].outline,"#abcdef")
        compare(clock.elementsLayout[0].stroke,3)
        compare(wallpaper.visualizerLinear.count,48)
        compare(wallpaper.visualizerLinear.edge,"right")
        compare(wallpaper.visualizerWidth,650)
        compare(wallpaper.visualizerHeight,540)
        compare(wallpaper.visualizerCenterX,910)
        compare(wallpaper.visualizerCenterY,555)
        const entry=links.document.entries[linkedUrl]
        verify(!!entry,"association persisted")
        compare(entry.clockProfile,clocks.activeId)
        compare(entry.audioProfile,audio.activeId)
        compare(clocks.count,2)
        compare(audio.count,2)
    }
}
