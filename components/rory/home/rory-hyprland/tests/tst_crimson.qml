pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "TaskbarModel.js" as Model

ShellRoot {
    id:tests
    function verify(ok,message){if(!ok)throw new Error(message)}
    function find(root,name){
        if(root.objectName===name)return root
        for(const child of root.children ?? []){
            const found=find(child,name)
            if(found)return found
        }
        return null
    }
    QtObject {
        id:links
        function taskbarProfile(url){return "global"}
    }
    QtObject {id:wallpaper;property string activeWallpaper:"file:///tmp/crimson-one.png"}
    QtObject {id:studio;property string page:"";property var targetScreen:Quickshell.screens[0]}
    CrimsonCoordinator {id:crimson;services:services}
    TaskbarStore {
        id:bars
        crimson:crimson
        storagePath:"file://"+Quickshell.shellPath(".taskbars.ini")
        associations:links;wallpaperSettings:wallpaper
    }
    SystemState {
        id:services
        property int wifiRequests:0
        property int bluetoothRequests:0
        function toggleWifi(){++wifiRequests}
        function toggleBluetooth(){++bluetoothRequests}
    }
    QtObject {id:fixturePlayer;property string trackArtUrl:Quickshell.shellPath("art/floral-center.svg")}
    QtObject {id:emptyPlayer;property string trackArtUrl:""}
    Window {
        visible:true;width:46;height:46
        CrimsonArtwork {id:artworkFixture;anchors.fill:parent;active:true;player:fixturePlayer;accent:"red"}
    }
    WindowCoverage {id:coverage}
    WallpaperSettings {id:roryWallpaper;studioVisibility:false}
    ClockSettings {id:clock;storagePath:"file://"+Quickshell.shellPath(".clock-settings.ini")}
    StudioController {
        id: prefs
        storagePath:"file://"+Quickshell.shellPath(".studio-settings.ini")
        clockSettings:clock;wallpaperSettings:roryWallpaper;clockManager:null;audioManager:null
    }
    RoryBar {
        id:roryBar
        modelData:Quickshell.screens[0]
        services:services;wallpaperSettings:roryWallpaper
        crimson:crimson;crimsonConfig:prefs.effectiveRoryCrimson;theme:prefs.roryBarTheme
    }
    Loader {
        id:fixture
        active:!!bars.bar
        sourceComponent:TaskbarPanel {
            barId:bars.bar.id;output:Quickshell.screens[0];store:bars;studio:studio;services:services;coverage:coverage
        }
    }
    Timer {
        interval:120;running:true;repeat:true
        property int stage:0
        property int attempts:0
        onTriggered:{
            try {
                if(!bars.ready)return
                if(stage===0){
                    if(Quickshell.env("RORY_CRIMSON_PHASE")==="restart"){
                        tests.verify(bars.bar.center.width===510 && bars.bar.center.quick[0].id==="flash","editor persisted appearance and order")
                        tests.verify(prefs.roryCrimson.width===468 && prefs.roryCrimson.background==="#20131e","original colors persisted separately")
                        tests.verify(prefs.globalBarTheme==="crimson" && prefs.globalCenterTheme==="sakura","global theme selections are independent and persisted")
                        console.log("CRIMSON_TEST_PASS");Qt.quit();return
                    }
                    prefs.globalBarTheme="crimson";prefs.globalCenterTheme="crimson"
                    const legacy=Model.bar("legacy","Anterior")
                    delete legacy.center
                    const old=Model.catalog()
                    old.layouts[0].bars.push(legacy)
                    tests.verify(Model.read(old).layouts[0].bars[0].center.opacity===.95,"migrate old taskbar")
                    prefs.saveRoryCrimson(Object.assign(Model.centerDefaults(),{width:468,duration:0}))
                    tests.find(roryBar.contentItem,"roryBarAudioIndicator").clicked()
                    tests.verify(crimson.visible && crimson.owner===roryBar && bars.bars.length===0,"RoryBar opens without modular bars")
                    crimson.close()
                    bars.create(false)
                    const appearance=Model.centerDefaults()
                    appearance.width=510
                    appearance.duration=0
                    appearance.quick.unshift(appearance.quick.pop())
                    tests.verify(bars.edit("global",bars.bar.id,{edge:"top",center:appearance}),bars.error)
                    const bad=Model.copy(appearance)
                    bad.width=4000
                    tests.verify(!bars.edit("global",bars.bar.id,{center:bad}),"invalid preset rejected")
                    fixture.item.toggleCenter(true)
                } else if(stage===1){
                    const pane=fixture.item
                    tests.verify(pane.centerOpen && !!pane.controlWindow,"center loaded")
                    const audio=tests.find(pane.contentItem,"taskbar-module-audio")
                    const windows=tests.find(pane.contentItem,"taskbar-module-windows")
                    tests.verify(audio && !audio.visible && windows && windows.visible,"only redundant taskbar items are hidden")
                    const shared=pane.controlWindow
                    const roryAudio=tests.find(roryBar.contentItem,"roryBarAudioIndicator")
                    const ornament=tests.find(roryBar.contentItem,"roryBarOrnament")
                    const originalWidth=ornament.width
                    pane.toggleCenter(false)
                    roryAudio.clicked()
                    tests.verify(!pane.centerOpen && crimson.owner===roryBar && crimson.window===shared,"RoryBar primary click uses the same Crimson surface")
                    tests.verify(shared.config.width===468 && bars.bar.center.width===510,"appearance does not leak between bars")
                    tests.verify(roryAudio.opacity===0 && ornament.width===originalWidth,"same bar geometry with status hidden")
                    const corner=tests.find(shared.contentItem,"crimsonRoryCorner0")
                    const filigree=tests.find(shared.contentItem,"crimsonFiligree")
                    tests.verify(corner.source.toString().endsWith("art/floral-corner.svg")
                        && filigree.source.toString()===ornament.source.toString(),"RoryBar ornament sources reused")
                    const statusPoint=roryAudio.mapToItem(null,roryAudio.width/2,roryAudio.height/2)
                    shared.dismissAt(statusPoint.x,statusPoint.y)
                    tests.verify(roryAudio.opacity===1 && !crimson.visible,"second click on the status area restores indicators")
                    roryAudio.clicked()
                    const escape=Array.from(shared.contentItem.data).find(item=>item.objectName==="crimsonEscape")
                    tests.verify(!!escape && escape.enabled,"Escape shortcut is active")
                    escape.activated()
                    tests.verify(!crimson.visible && roryAudio.opacity===1,"Escape restores indicators")
                    roryAudio.clicked()
                    shared.dismissAt(0,200)
                    tests.verify(!crimson.visible && roryAudio.opacity===1,"outside click restores indicators")
                    roryAudio.clicked()
                    const body=tests.find(shared.contentItem,"crimsonBody")
                    tests.verify(!tests.find(shared.contentItem,"crimsonAudioDetails")
                        && !tests.find(shared.contentItem,"crimsonBatteryDetails"),"no redundant header controls")
                    const wifi=tests.find(shared.contentItem,"crimsonWifiCard")
                    const bluetooth=tests.find(shared.contentItem,"crimsonBluetoothCard")
                    wifi.clicked()
                    tests.verify(services.wifiRequests===1 && shared.details==="","Wi-Fi left click only toggles")
                    tests.find(shared.contentItem,"crimson-loader-wifi").secondary()
                    tests.verify(shared.details==="wifi" && services.wifiRequests===1,"Wi-Fi secondary only opens networks")
                    const network=tests.find(shared.contentItem,"crimsonNetworkPanel")
                    let connected=0
                    network.connectNetwork({known:true,connect:()=>++connected})
                    tests.verify(connected===1,"known network dispatches connect")
                    shared.handleEscape()
                    tests.verify(shared.details==="" && crimson.visible,"Escape backs out of Wi-Fi")
                    bluetooth.clicked()
                    tests.verify(services.bluetoothRequests===1 && shared.details==="","Bluetooth left click only toggles")
                    tests.find(shared.contentItem,"crimson-loader-bluetooth").secondary()
                    tests.verify(shared.details==="bluetooth" && services.bluetoothRequests===1,"Bluetooth secondary opens devices")
                    const bt=tests.find(shared.contentItem,"crimsonBluetoothPanel")
                    let deviceEvents=[]
                    const fake={connect:()=>deviceEvents.push("connect"),disconnect:()=>deviceEvents.push("disconnect")}
                    bt.deviceAction("connect",fake)
                    bt.deviceAction("disconnect",fake)
                    tests.verify(deviceEvents.join(",")==="connect,disconnect","Bluetooth sends device actions")
                    tests.find(shared.contentItem,"crimsonBack").clicked()
                    tests.verify(shared.details==="" && crimson.visible,"Back returns to controls")
                    const art=tests.find(artworkFixture,"crimsonCover")
                    tests.verify(art.visible && art.source.toString().endsWith("floral-center.svg"),"MPRIS local cover requested")
                    fixturePlayer.trackArtUrl=Quickshell.shellPath("art/floral-corner.svg")
                    body.legacyRequested("audio")
                    tests.verify(roryBar.activePage==="audio" && !crimson.visible,"Crimson opens the original audio panel")
                    roryAudio.clicked()
                    tests.find(shared.contentItem,"crimsonBody").legacyRequested("battery")
                    tests.verify(roryBar.activePage==="battery" && !crimson.visible,"Crimson opens original battery panel")
                    pane.toggleCenter(true)
                    tests.verify(crimson.window===shared && shared.config.width===510,"modular integration keeps its configuration")
                    pane.toggleCenter(false)
                    tests.verify(audio.visible,"same audio module restored")
                    for(let i=0;i<12;i++){pane.toggleCenter(true);pane.toggleCenter(false)}
                    pane.toggleCenter(true)
                    wallpaper.activeWallpaper="file:///tmp/crimson-two.png"
                    tests.verify(audio.visible && !pane.centerOpen,"wallpaper change closes the center")
                    roryAudio.clicked()
                } else if(stage===2){
                    const pane=fixture.item
                    const art=tests.find(artworkFixture,"crimsonCover")
                    if ((!art.visible || !art.source.toString().endsWith("floral-corner.svg")) && attempts++<12)return
                    attempts=0
                    tests.verify(art.visible && art.source.toString().endsWith("floral-corner.svg"),"MPRIS changes update the requested artwork")
                    artworkFixture.player=emptyPlayer
                    tests.verify(tests.find(artworkFixture,"crimsonCoverFallback").visible && art.source.toString()==="","new player without artwork restores fallback")
                    const content=pane.controlWindow.contentItem
                    const card=tests.find(content,"crimsonCard")
                    const body=tests.find(content,"crimsonBody")
                    const connectivity=tests.find(content,"crimsonConnectivity")
                    const mediaRow=tests.find(content,"crimsonMediaRow")
                    const media=tests.find(content,"crimsonMedia")
                    const brightness=tests.find(content,"crimsonBrightness")
                    const volume=tests.find(content,"crimsonVolume")
                    const kde=tests.find(content,"crimsonKde")
                    const grid=tests.find(content,"crimsonQuickGrid")
                    body.forceLayout()
                    if ((connectivity.width < body.width-2 || body.implicitHeight===0 || grid.y===0) && attempts++ < 8) return
                    attempts=0
                    const button=tests.find(content,"crimson-control-flash")
                    tests.verify(Math.abs(card.height-Math.min(pane.controlWindow.config.height,pane.controlWindow.height-card.y-8,body.implicitHeight+card.header+card.footer))<2,"height follows content")
                    tests.verify(connectivity.y<mediaRow.y && mediaRow.y<grid.y && grid.columns===4,"Android row order and four columns")
                    tests.verify(media.width>brightness.width*1.6 && brightness.height===volume.height && brightness.height>=150,"balanced media and slider sizes")
                    tests.verify(kde.width>=body.width-2 && button.width===button.height,"full-width KDE and circular actions")
                    const names={airplane:"Modo avión",dnd:"No molestar",power:"Ahorro",record:"Grabar",
                        night:"Noche",capture:"Captura",settings:"Configuración",flash:"Linterna"}
                    for (const id of Object.keys(names)) {
                        const label=tests.find(content,"crimson-label-"+id)
                        const tile=tests.find(content,"crimson-control-"+id)
                        tests.verify(label?.visible && label.text===names[id] && !label.truncated,"legible label: "+id)
                        tests.verify(label.y>=tile.y+tile.height && label.y+label.height<=label.parent.height,"label stays in its slot: "+id)
                    }
                    tests.verify(!!button,"flash control available")
                    button.clicked()
                } else if(stage===3){
                    const pane=fixture.item
                    if(!pane.controlWindow.flashlightActive && attempts++<12)return
                    tests.verify(pane.controlWindow.flashlightActive,"flash opens after guardian acknowledgement")
                    crimson.close()
                    tests.verify(pane.controlWindow.flashlightActive,"flash stays dismissible after center closes")
                    const off=tests.find(pane.controlWindow.flashlightWindow.contentItem,"crimsonFlashOff")
                    tests.verify(off && off.visible,"flash has independent visible off button")
                    off.clicked()
                    tests.verify(!pane.controlWindow.flashlightActive,"flash off closes the temporary surface")
                    prefs.saveRoryCrimson(Object.assign({},prefs.roryCrimson,{width:280}))
                    roryBar.openCrimson()
                } else if(stage===4){
                    const content=crimson.window.contentItem
                    const label=tests.find(content,"crimson-label-settings")
                    const tile=tests.find(content,"crimson-control-settings")
                    if ((!label.visible || label.parent.width<=0 || label.width>=100) && attempts++<8)return
                    tests.verify(label.visible && label.text==="Configuración" && !label.truncated
                        && label.contentWidth<=label.width+1 && label.y+label.height<=label.parent.height
                        && label.y>=tile.height,"long name fits at minimum width")
                    prefs.saveRoryCrimson(Object.assign({},prefs.roryCrimson,{width:620,background:"#20131e"}))
                    prefs.globalBarTheme="sakura"
                    prefs.globalCenterTheme="sakura"
                } else if(stage===5){
                    const window=crimson.window
                    const card=tests.find(window.contentItem,"crimsonCard")
                    const body=tests.find(window.contentItem,"crimsonBody")
                    body.forceLayout()
                    tests.verify(card.width===390 && card.gutter===12 && body.spacing===8,"compact Sakura dimensions")
                    tests.verify(window.paint.background==="#120B14" && window.paint.accent==="#F02F7E","Sakura palette")
                    const ornament=tests.find(roryBar.contentItem,"roryBarOrnament")
                    tests.verify(ornament.source.toString().endsWith("sakura-floral-center.svg"),"Sakura recolors the original RoryBar filigree")
                    const preview=Quickshell.env("RORY_CRIMSON_PREVIEW")
                    if(preview)card.grabToImage(result=>result.saveToFile(preview))
                } else if(stage===6){
                    prefs.globalBarTheme="crimson"
                    prefs.globalCenterTheme="crimson"
                    tests.verify(crimson.window.paint.background==="#20131e","switching back restores the user's original color")
                    tests.verify(tests.find(roryBar.contentItem,"roryBarOrnament").source.toString()==="art/floral-center.svg","switching back restores original ornament")
                    prefs.globalCenterTheme="sakura"
                    prefs.saveRoryCrimson(Object.assign({},prefs.roryCrimson,{width:468}))
                    console.log("CRIMSON_TEST_PASS");Qt.quit();return
                }
                ++stage
            }catch(e){console.error("CRIMSON_TEST_FAIL: "+e);Qt.quit()}
        }
    }
}
