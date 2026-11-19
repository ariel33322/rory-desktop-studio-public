import QtQuick
import QtTest
import "StudioProfiles.js" as Profiles

TestCase {
    id: tests
    name: "ClockProfiles"
    when: windowShown
    visible: true
    width: 700; height: 600
    ClockSettings {id: settings;storagePath:Qt.resolvedUrl(".clock-settings.ini")}
    ClockProfileManager {id: manager; settings: settings}
    StudioProfileBar {id:bar;manager:manager;width:480}
    StudioColorEditor {id:color;controller:manager.controller;value:settings.textColor;contextKey:manager.activeId;onColorEdited:c=>settings.textColor=c}
    VisualizerSlider {id:size;controller:manager.controller;label:"Hora";explanation:"";from:8;to:300;value:settings.timeSize;onValueEdited:v=>settings.timeSize=v}
    Item {
        id: desktop
        width: 700; height: 600
        Item {
            id: face
            x: settings.leftPercent * desktop.width
            y: settings.topPercent * desktop.height
            width: settings.widgetWidth
            height: settings.widgetHeight
        }
        ClockPointerEdit {id:pointer;anchors.fill:parent;screen:desktop;settings:settings;face:face}
    }
    function exercisePointer() {
        settings.leftPercent=0.1;settings.topPercent=0.1
        settings.customWidth=250;settings.customHeight=220
        settings.pointerEditMode=true
        mousePress(pointer,100,100,Qt.LeftButton)
        mouseMove(pointer,120,125,20,Qt.LeftButton)
        mouseMove(pointer,157,169,20,Qt.LeftButton)
        mouseRelease(pointer,157,169,Qt.LeftButton)
        verify(settings.leftPercent > 0.1)
        verify(settings.topPercent > 0.1)
        const x = face.x + face.width - 12, y = face.y + face.height - 12
        mousePress(pointer,x,y,Qt.LeftButton)
        mouseMove(pointer,x+18,y+24,20,Qt.LeftButton)
        mouseMove(pointer,x+51,y+68,20,Qt.LeftButton)
        mouseRelease(pointer,x+51,y+68,Qt.LeftButton)
        verify(settings.customWidth > 250)
        verify(settings.customHeight > 220)
        verify(settings.customWidth - 250 !== settings.customHeight - 220)
        settings.pointerEditMode=false
        settings.leftPercent=0.12;settings.topPercent=0.38
    }
    Rectangle {
        id:outlineSample
        x:480;y:280;width:160;height:110;color:"black"
        ClockOutlineText {
            id:glyph
            anchors.fill:parent
            text:"88";horizontalAlignment:Text.AlignHCenter
            font.pixelSize:76
            settings:settings
            fillColor:"#ff0000"
            originalOutline:"#55ffffff"
        }
    }
    function bluePixels() {
        const image=grabImage(outlineSample)
        let count=0
        for(let y=0;y<image.height;++y)
            for(let x=0;x<image.width;++x)
                if(image.blue(x,y)>30 && image.red(x,y)<20 && image.green(x,y)<20)++count
        return count
    }
    function exerciseOutline() {
        compare(glyph.style,Text.Outline)
        compare(glyph.outlineInk,"#55ffffff")
        settings.outlineColor="#0000ff"
        settings.outlineOpacity=.8
        compare(glyph.outlineInk,Qt.rgba(0,0,1,.8))
        tryVerify(() => bluePixels()>0)
        const thin=bluePixels()
        settings.outlineWidth=6
        verify(glyph.vectorOutline)
        tryVerify(() => bluePixels()>thin)
        settings.outlineEnabled=false
        compare(glyph.style,Text.Normal)
        tryVerify(() => bluePixels()===0)
        settings.outlineEnabled=true
    }
    function test_profiles() {
        compare(color.parse("rgb(18,52,86)"),"#123456")
        compare(color.parse("255 0 128"),"#ff0080")
        compare(color.parse("#ABCDEF"),"#abcdef")
        compare(color.parse("256 0 0"),"")

        tryCompare(manager,"ready",true)
        compare(manager.count, 1)
        compare(settings.timeSize,127)
        compare(settings.leftPercent,0.12)
        compare(settings.widgetOpacity,0.91)
        compare(manager.activeProfile.snapshot.timeSize,127)
        compare(manager.activeProfile.snapshot.leftPercent,0.12)
        const original = manager.activeId
        exercisePointer()
        exerciseOutline()
        settings.timeSize = 90
        settings.customWidth = 640
        settings.customHeight = 360
        settings.clockRotation = 25
        settings.fontFamily = "Serif"
        settings.fontWeight = 700
        settings.textColor = "#123456"
        settings.showSeconds = true
        settings.showDate = false
        settings.backgroundEnabled = true
        settings.backgroundColor = "#abcdef"
        settings.backgroundOpacity = 0.4
        settings.backgroundRadius = 28
        const snapshot = settings.snapshot()
        const id = manager.createProfile("Mi reloj")
        verify(id !== "", manager.error)
        compare(manager.count, 2)
        verify(manager.renameProfile(id,"Mi reloj guardado"))
        verify(!manager.renameProfile(id,"Reloj actual"))
        settings.timeSize = 100
        verify(manager.dirty)
        verify(!manager.activateProfile(original))
        verify(!!manager.pendingChange)
        manager.resolvePending("cancel")
        compare(settings.timeSize, 100)
        manager.activateProfile(original)
        manager.resolvePending("save")
        compare(settings.timeSize, 127)
        compare(settings.outlineColor,"")
        compare(settings.outlineWidth,1)
        verify(manager.activateProfile(id))
        compare(settings.timeSize, 100)
        settings.timeSize = snapshot.timeSize
        verify(manager.saveProfile(id,false))
        verify(!manager.dirty)
        const duplicate = manager.duplicateProfile(id)
        verify(duplicate !== "")
        verify(manager.activateProfile(duplicate))
        compare(Profiles.signature(settings.snapshot()), Profiles.signature(snapshot))
        manager.requestDelete(duplicate)
        manager.confirmDelete(false)
        compare(manager.count,3)
        manager.requestDelete(duplicate)
        manager.confirmDelete(true)
        compare(manager.count,2)
        compare(manager.activeId, "")
        verify(!manager.dirty, "deleting an unchanged active profile preserves a clean detached clock")
        compare(Profiles.signature(settings.snapshot()), Profiles.signature(snapshot))
        manager.requestLoad(id,"manual","")
        manager.resolvePending("discard")
        compare(manager.activeId,id)
        manager.requestDelete(original)
        manager.confirmDelete(true)
        compare(manager.count,1)
        verify(!manager.canDeleteProfile(id))
        const old=manager.catalog
        let rejected=false
        try { manager.validate(Object.assign({},snapshot,{timeSize:NaN})) } catch(e) {rejected=true}
        verify(rejected)
        compare(manager.catalog,old)
        // Verify legacy v1.0.0 snapshot migration with 22 missing keys
        const legacySnapshot = {
            timeSize: 85, accent: "#123456", textColor: "#f3eef0",
            title: "Rory", signature: "Mercury", widgetOpacity: 0.9,
            leftPercent: 0.1, topPercent: 0.2, use24Hour: false
        }
        const validated = manager.validate(legacySnapshot)
        compare(validated.customWidth, 0)
        compare(validated.customHeight, 0)
        compare(validated.fontFamily, "Noto Sans")
        compare(validated.backgroundImage, "")
        compare(validated.backgroundEnabled, false)
        compare(validated.timeSize, 85)
        compare(validated.outlineColor,"")
        compare(validated.outlineWidth,1)
    }
    function test_restart() {
        // The runner invokes this case alone in the second process.
        tryCompare(manager,"ready",true)
        compare(manager.count,1)
        compare(manager.profileName(manager.activeId),"Mi reloj guardado")
        compare(settings.timeSize,90)
        compare(settings.widgetWidth,640)
        compare(settings.widgetHeight,360)
        compare(settings.clockRotation,25)
        compare(settings.backgroundColor,"#abcdef")
        compare(settings.showSeconds,true)
        compare(settings.showDate,false)
        compare(settings.outlineColor,"#0000ff")
        compare(settings.outlineWidth,6)
        compare(settings.outlineOpacity,.8)
        verify(settings.outlineEnabled)
        verify(!manager.dirty)
        settings.timeSize=99
        verify(manager.dirty)
    }
    function test_draftRestart() {
        tryCompare(manager,"ready",true)
        compare(settings.timeSize,99)
        compare(manager.activeProfile.snapshot.timeSize,90)
        verify(manager.dirty)
    }
}
