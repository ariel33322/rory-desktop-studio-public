pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "RoryTheme.js" as Theme

PanelWindow {
    id: center
    required property ShellScreen output
    required property var config
    readonly property var paint:Theme.center(config)
    readonly property bool sakura:paint.theme==="sakura"
    required property SystemState services
    required property bool open
    required property real anchorY
    property real rightInset: 12
    required property var closeRequest
    property bool legacyDetails:false
    property var legacyRequest:null
    function dismissAt(x,y) {
        if (open && (x<card.x || y<card.y || x>=card.x+card.width || y>=card.y+card.height))
            closeRequest()
    }
    property string details: ""
    onDetailsChanged:scroll.contentY=0
    function handleEscape() {
        if(details!=="")details=""
        else closeRequest()
    }
    readonly property bool flashlightActive: backend.flash
    readonly property bool flashlightBusy: backend.flash || backend.flashStarting
    function stopFlash() { backend.stopFlash() }
    readonly property var flashlightWindow: torch
    screen:output
    anchors {top:true;bottom:true;left:true;right:true}
    exclusionMode:ExclusionMode.Ignore
    color:"transparent"
    visible:open || card.opacity>0
    WlrLayershell.namespace:"rory-crimson-control"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask:Region {width:center.open ? center.width : 0;height:center.open ? center.height : 0}
    Component.onDestruction:if(open && closeRequest)closeRequest()
    onOpenChanged: {
        if(open) card.forceActiveFocus()
        else details=""
    }
    Shortcut {objectName:"crimsonEscape";sequence:"Escape";enabled:center.open;onActivated:center.handleEscape()}
    MouseArea {
        objectName:"crimsonDismissArea"
        anchors.fill:parent;enabled:center.open
        acceptedButtons:Qt.AllButtons
        onClicked: event=>center.dismissAt(event.x,event.y)
    }
    CrimsonBackend {id:backend;output:center.output?.name ?? "";open:center.open}
    Rectangle {
        id:card
        width:Math.max(1,Math.min(center.paint.width,center.width-16))
        readonly property int gutter:Math.round(Math.max(center.sakura ? 10 : 14,center.sakura ? Math.min(12,width*.032) : Math.min(36,width*.054)))
        readonly property int header:Math.round(center.sakura ? 29 : Math.max(32,Math.min(42,width*.066)))
        readonly property int footer:center.paint.decorative ? Math.max(gutter,center.sakura ? 23 : 30) : gutter
        readonly property real naturalHeight: controlBody.implicitHeight+header+footer
        height:Math.max(1,Math.min(center.paint.height,center.height-y-8,naturalHeight))
        objectName:"crimsonCard"
        x:Math.max(8,Math.min(center.width-width-8,center.width-width-center.rightInset+center.paint.x))
        y:Math.max(8,Math.min(center.height-140,center.anchorY+center.paint.y))
        opacity:center.open ? 1 : 0
        transform:Translate {
            y:center.open ? 0 : -10
            Behavior on y {NumberAnimation {duration:center.paint.duration;easing.type:Easing.OutCubic}}
        }
        Behavior on opacity {NumberAnimation {duration:center.paint.duration;easing.type:Easing.OutCubic}}
        readonly property color tint:center.paint.background
        readonly property bool roryPalette:center.paint.background==="#130a11"
        function surface(red,green,blue) {
            return roryPalette ? Qt.rgba(red/255,green/255,blue/255,center.paint.opacity)
                : Qt.rgba(tint.r,tint.g,tint.b,center.paint.opacity)
        }
        gradient:Gradient {
            GradientStop {position:0;color:card.surface(17,9,14)}
            GradientStop {position:.5;color:card.surface(12,9,13)}
            GradientStop {position:1;color:card.surface(18,9,14)}
        }
        radius:center.paint.radius
        border.color:center.paint.border==="#8a2445" ? "#b1162e" : center.paint.border
        border.width:center.paint.borderWidth
        Rectangle {
            z:-1;x:1;y:5;width:parent.width;height:parent.height
            radius:parent.radius;color:"#52000000"
        }
        Rectangle {
            anchors.fill:parent
            anchors.margins:3
            radius:Math.max(0,card.radius-3)
            color:"transparent"
            border.color:Theme.tone(center.paint.theme,"#810f25",Theme.fuchsia)
            border.width:center.paint.decorative && center.paint.borderWidth>0 ? 1 : 0
        }
        Image {
            objectName:"crimsonFiligree"
            anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter
            width:Math.min(220,parent.width*.4);height:card.header-5
            visible:center.paint.decorative || center.paint.decoration!==""
            source:center.paint.decoration ? (center.paint.decoration.startsWith("/") ? "file://"+center.paint.decoration : center.paint.decoration)
                : Theme.art(center.paint.theme,"floral-center")
            fillMode:Image.PreserveAspectFit
            opacity:.928
        }
        Image {
            anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter
            width:Math.min(205,parent.width*.38);height:card.footer-3
            visible:center.paint.decorative
            source:Theme.art(center.paint.theme,"floral-center")
            fillMode:Image.PreserveAspectFit
        }
        Repeater {
            model:center.paint.decorative ? [0,1,2,3] : []
            delegate:Image {
                id:corner
                required property int modelData
                objectName:"crimsonRoryCorner"+modelData
                readonly property bool lowerCorner:modelData>=2
                x:modelData%2 ? card.width-width-2 : 2
                y:lowerCorner ? card.height-height-1 : 1
                height:Math.min(65,card.width*.105);width:height*86/108
                source:Theme.art(center.paint.theme,"floral-corner")
                fillMode:Image.PreserveAspectFit
                mirror:modelData%2===1
                transform:Scale {origin.y:corner.height/2;yScale:corner.lowerCorner ? -1 : 1}
                opacity:.92
            }
        }
        Flickable {
            id:scroll
            anchors.fill:parent
            anchors.margins:card.gutter
            anchors.topMargin:card.header
            anchors.bottomMargin:card.footer
            contentWidth:width
            contentHeight:controlBody.implicitHeight
            flickableDirection:Flickable.VerticalFlick
            boundsBehavior:Flickable.StopAtBounds
            clip:true
            ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
            CrimsonControls {
                id:controlBody
                width:scroll.width
                config:center.paint
                services:center.services
                backend:backend
                details:center.details
                mediaVisible:center.open && center.details===""
                onRevealTop:scroll.contentY=0
                legacyAvailable:center.legacyDetails
                onLegacyRequested:page=>center.legacyRequest(page)
                onShowDetails:name=>center.details=name
                onCloseRequested:center.closeRequest()
            }
        }
    }
    PanelWindow {
        id:torch
        screen:center.output
        visible:backend.flash
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        color:"white"
        WlrLayershell.namespace:"rory-crimson-flash"
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Shortcut {sequence:"Escape";enabled:torch.visible;onActivated:backend.stopFlash()}
        Column {
            anchors.centerIn:parent
            spacing:14
            Button {
                id: cancelFlash
                objectName:"crimsonFlashOff"
                anchors.horizontalCenter:parent.horizontalCenter
                width:Math.min(torch.width-16,220);height:112
                text:"Apagar linterna"
                onClicked:backend.stopFlash()
                contentItem:Text {
                    text:cancelFlash.text;color:"white";font.pixelSize:22;font.bold:true
                    horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                }
                background:Rectangle {radius:24;color:"#100e10";border.color:center.paint.accent;border.width:3}
            }
            Text {anchors.horizontalCenter:parent.horizontalCenter;text:"Esc también la apaga";color:"#1a1119";font.pixelSize:15}
        }
    }
}
