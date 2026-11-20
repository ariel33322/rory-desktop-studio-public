pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "TaskbarModel.js" as Model
import "RoryTheme.js" as Theme

PanelWindow {
    id: panel
    required property ShellScreen output
    required property string barId
    required property var store
    required property var studio
    required property var services
    required property var coverage
    readonly property var config: store.bars.find(b=>b.id===barId) ?? Model.bar(barId,"Barra")
    readonly property var themedConfig:Theme.taskbar(config)
    readonly property var monitor: Hyprland.monitorFor(output)
    readonly property bool vertical: config.orientation==="vertical"
    readonly property bool editing: studio.page==="taskbars" && store.dragging && store.bar?.id===barId && studio.targetScreen===output
    readonly property var centerSettings: config.center ?? Model.centerDefaults()
    readonly property var crimson: store.crimson
    readonly property var crimsonOutput: output
    readonly property var crimsonConfig: centerSettings
    readonly property real crimsonAnchorY: config.edge==="top" ? geometry.y+geometry.height : 0
    readonly property var controlWindow: crimson?.window ?? null
    readonly property bool hideUpperStatus: config.edge==="top" && !!crimson?.visible && crimson.output===output
    readonly property bool centerOpen: !!crimson?.visible && crimson.owner===panel
    function toggleCenter(open) {
        if (open && crimson) {
            calendarOpen=false
            crimson.openFor(panel)
        } else if (centerOpen) crimson.close()
    }
    onCenterOpenChanged:if(!centerOpen){hoverCooldown.restart();leave()}
    Component.onDestruction: crimson?.release(panel)
    onCenterSettingsChanged: if (!centerSettings.enabled) crimson?.release(panel)
    Timer {id:hoverCooldown;interval:600}
    readonly property bool suppressed: config.hideCovered && coverage.isCovered(output.name,"taskbar")
    readonly property bool reveal: editing || centerOpen || (!suppressed && (!config.autohide || held || calendarOpen))
    readonly property var geometry: Model.rect(preview ?? config,width,height)
    readonly property bool side: config.edge==="left" || config.edge==="right"
    readonly property string moduleOrder: config.modules.filter(m=>m.enabled).map(m=>m.id).join(",")
    property bool held: false
    property bool calendarOpen: false
    property var preview: null
    screen:output
    anchors {top:true;bottom:true;left:true;right:true}
    exclusionMode:ExclusionMode.Ignore
    color:"transparent"
    WlrLayershell.namespace:"rory-taskbar-"+barId
    WlrLayershell.layer:WlrLayer.Top
    WlrLayershell.keyboardFocus: calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        width:0;height:0
        Region { item: panel.reveal ? face : null }
        Region { item: trigger.visible ? trigger : null }
        Region { item: calendar.visible ? calendar : null }
    }
    BackgroundEffect.blurRegion: config.blur && reveal ? blurRegion : null
    Region { id:blurRegion; item:face; radius:panel.config.radius }
    onEditingChanged: if (!editing) preview=null
    onSuppressedChanged: if (suppressed) { held=false; calendarOpen=false }
    onConfigChanged: if (!config.modules.some(m=>m.id==="clock" && m.enabled)) calendarOpen=false
    function enter() { hideTimer.stop(); held=true }
    function leave() { if (!bodyHover.hovered && !edgeHover.hovered) hideTimer.restart() }
    Timer { id:hideTimer; interval:panel.config.delay; onTriggered:panel.held=false }

    Item {
        id: trigger
        visible: panel.config.autohide && !panel.suppressed && !panel.editing
        readonly property var area: {
            const g=panel.geometry
            const thickness=panel.config.trigger
            const bridge=panel.reveal
            switch(panel.config.edge) {
                case "left": return Qt.rect(0,g.y,bridge ? g.x+1 : thickness,g.height)
                case "right": {
                    const x=bridge ? g.x+g.width-1 : panel.width-thickness
                    return Qt.rect(x,g.y,panel.width-x,g.height)
                }
                case "top": return Qt.rect(g.x,0,g.width,bridge ? g.y+1 : thickness)
                case "bottom": {
                    const y=bridge ? g.y+g.height-1 : panel.height-thickness
                    return Qt.rect(g.x,y,g.width,panel.height-y)
                }
                default: return Qt.rect(g.x,g.y,panel.vertical ? thickness : g.width,panel.vertical ? g.height : thickness)
            }
        }
        x:area.x; y:area.y; width:area.width; height:area.height
        HoverHandler { id:edgeHover; onHoveredChanged: hovered ? panel.enter() : panel.leave() }
    }

    Rectangle {
        id: face
        x:panel.geometry.x
        y:panel.geometry.y
        width:panel.geometry.width
        height:panel.geometry.height
        opacity:panel.reveal ? 1 : 0
        visible:opacity>0
        radius:panel.config.radius
        color:Qt.rgba(ink.r,ink.g,ink.b,panel.config.opacity)
        readonly property color ink:panel.themedConfig.background
        border.color: panel.editing ? "#ff9bbf" : panel.themedConfig.border
        border.width:panel.editing ? Math.max(2,panel.config.borderWidth) : panel.config.borderWidth
        Behavior on width { enabled:!panel.editing; NumberAnimation { duration:panel.config.duration; easing.type:Easing.OutCubic } }
        Behavior on height { enabled:!panel.editing; NumberAnimation { duration:panel.config.duration; easing.type:Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration:panel.config.duration; easing.type:Easing.OutCubic } }
        Rectangle {
            z:-1
            visible:panel.config.shadow>0
            y:Math.ceil(panel.config.shadow/2)
            x:2;width:parent.width;height:parent.height
            radius:parent.radius
            color:Qt.rgba(0,0,0,Math.min(.65,panel.config.shadow/24))
        }
        HoverHandler { id:bodyHover; enabled:panel.reveal;onHoveredChanged:hovered ? panel.enter() : panel.leave() }
        Flickable {
            anchors.fill:parent
            anchors.margins:Math.min(panel.config.padding,(Math.min(parent.width,parent.height)-1)/2)
            clip:true
            interactive:!panel.editing
            flickableDirection:panel.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            contentWidth:panel.vertical ? width : modules.implicitWidth
            contentHeight:panel.vertical ? modules.implicitHeight : height
            boundsBehavior:Flickable.StopAtBounds
            GridLayout {
                id:modules
                columns:panel.vertical ? 1 : 999
                columnSpacing:panel.config.spacing
                rowSpacing:columnSpacing
                y:panel.vertical ? 0 : Math.max(0,(parent.height-height)/2)
                Repeater {
                    model:panel.moduleOrder ? panel.moduleOrder.split(",") : []
                    TaskbarModule {
                        required property string modelData
                        objectName:"taskbar-module-"+modelData
                        kind:modelData
                        config:panel.themedConfig
                        services:panel.services
                        monitor:panel.monitor
                        panel:panel
                        visible:available && !(panel.hideUpperStatus && ["audio","battery","network"].includes(kind))
                    }
                }
                TaskbarButton {
                    id: centerButton
                    visible:panel.centerSettings.enabled
                    config:panel.themedConfig
                    glyph:"☷"
                    selected:panel.centerOpen
                    description:"Centro de control carmesí"
                    onClicked:panel.toggleCenter(!panel.centerOpen)
                    onHoveredChanged:{
                        if(hovered && panel.centerSettings.openOnHover && !panel.centerOpen && !hoverCooldown.running) hoverOpen.restart()
                        else hoverOpen.stop()
                    }
                    Timer {id:hoverOpen;interval:350;onTriggered:if(centerButton.hovered)panel.toggleCenter(true)}
                }
            }
        }
        MouseArea {
            anchors.fill:parent
            enabled:panel.editing
            visible:enabled
            preventStealing:true
            cursorShape:Qt.SizeAllCursor
            property point start
            property var original
            property var dimensions
            property string profile
            onPressed:event=>{
                start=mapToItem(null,event.x,event.y)
                original=panel.config
                dimensions=panel.geometry
                profile=panel.store.profileId
            }
            onPositionChanged:event=>{
                if (!pressed || profile!==panel.store.profileId) return
                const at=mapToItem(null,event.x,event.y)
                panel.preview=Model.move(Object.assign({},original),dimensions,at.x-start.x,at.y-start.y)
            }
            onReleased:{
                if(panel.preview && profile===panel.store.profileId)
                    panel.store.edit(profile,panel.barId,{x:panel.preview.x,y:panel.preview.y,inset:panel.preview.inset})
                panel.preview=null
            }
            onCanceled:panel.preview=null
        }
    }

    Rectangle {
        id:calendar
        visible:panel.calendarOpen && panel.reveal
        width:Math.min(292,panel.width)
        height:Math.min(250,panel.height)
        x:Math.max(0,Math.min(panel.width-width, panel.side && panel.config.edge==="left" ? face.x+face.width+4 : face.x))
        y:Math.max(0,Math.min(panel.height-height,face.y>height ? face.y-height-4 : face.y+face.height+4))
        color:"#261b23"
        border.color:panel.config.border
        radius:9
        property date date:new Date()
        function navigate(delta) {date=new Date(date.getFullYear(),date.getMonth()+delta,1)}
        ColumnLayout {
            anchors.fill:parent
            anchors.margins:8
            RowLayout {
                StudioToolButton {text:"‹";onClicked:calendar.navigate(-1)}
                Label {Layout.fillWidth:true;text:Qt.formatDate(calendar.date,"MMMM yyyy");color:panel.config.textColor}
                StudioToolButton {text:"›";onClicked:calendar.navigate(1)}
                StudioToolButton {text:"×";onClicked:{panel.calendarOpen=false;panel.leave()}}
            }
            DayOfWeekRow {Layout.fillWidth:true;delegate:Label {required property string shortName;text:shortName;color:panel.config.textColor;horizontalAlignment:Text.AlignHCenter}}
            MonthGrid {
                Layout.fillWidth:true;Layout.fillHeight:true
                month:calendar.date.getMonth();year:calendar.date.getFullYear()
                delegate:Label {
                    required property var model
                    text:model.day
                    color:model.today ? "#ff98b7" : panel.config.textColor
                    opacity:model.month===calendar.date.getMonth() ? 1 : .45
                    horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                }
            }
        }
    }
    Shortcut { sequence:"Escape";enabled:panel.calendarOpen;onActivated:{panel.calendarOpen=false;panel.leave()} }
}
