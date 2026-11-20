pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "RoryTheme.js" as Theme

Slider {
    id:slider
    required property var config
    required property string symbol
    required property string title
    property real uiScale:1
    readonly property bool sakura:config.theme==="sakura"
    property string iconKind:""
    property string unavailable:""
    property real confirmedLevel:-1
    property bool changing:false
    readonly property real displayLevel: (pressed || changing) && enabled ? value : confirmedLevel
    orientation:Qt.Vertical
    from:0;to:1
    implicitWidth:65;implicitHeight:158
    leftPadding:0;rightPadding:0;topPadding:0;bottomPadding:0
    Accessible.name:title
    Accessible.description:enabled ? Math.round(displayLevel*100)+" %" : unavailable
    hoverEnabled:true
    Binding {
        slider.value:Math.max(0,slider.confirmedLevel)
        when:!slider.pressed && !slider.changing
        restoreMode:Binding.RestoreNone
    }
    background:Rectangle {
        anchors.fill:parent
        radius:Math.min(width/2,30*slider.uiScale)
        color:Theme.tone(slider.config.theme,"#210f18",Theme.plum)
        border.color:slider.activeFocus ? slider.config.accent : "#9b2146"
        Rectangle {
            anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter
            anchors.bottomMargin:1
            width:Math.max(0,parent.width-2)
            height:Math.max(0,(parent.height-2)*Math.max(0,slider.displayLevel))
            radius:Math.min(height/2,parent.radius)
            gradient:Gradient {
                GradientStop {position:0;color:slider.enabled ? Theme.tone(slider.config.theme,"#fa7da5",Theme.pale) : "#644452"}
                GradientStop {position:1;color:slider.enabled ? Theme.tone(slider.config.theme,"#db3d6b",Theme.fuchsia) : "#533241"}
            }
        }
        Item {
            anchors.top:parent.top;anchors.topMargin:Math.round(12*slider.uiScale)
            anchors.horizontalCenter:parent.horizontalCenter
            width:Math.round(slider.config.iconSize*slider.uiScale);height:width
            SakuraIcon {
                visible:slider.sakura
                anchors.fill:parent
                kind:slider.iconKind==="" ? "brightness" : slider.symbol==="×" ? "muted" : "volume"
                usable:slider.enabled
            }
            RoryGlyph {visible:!slider.sakura && slider.iconKind!=="";anchors.fill:parent;kind:slider.iconKind;ink:"#f8bfd3";level:Math.max(0,slider.displayLevel);off:slider.symbol==="×"}
            Text {visible:!slider.sakura && slider.iconKind==="";anchors.centerIn:parent;text:slider.symbol;color:"#f8bfd3";font.pixelSize:parent.width}
        }
        Text {
            anchors.horizontalCenter:parent.horizontalCenter
            anchors.bottom:parent.bottom;anchors.bottomMargin:Math.round(10*slider.uiScale)
            text:slider.displayLevel>=0 ? Math.round(slider.displayLevel*100)+"%" : "—"
            color:slider.enabled && slider.displayLevel>.24 ? "#26101b" : "#fff0f4"
            font.pixelSize:Math.round(15*slider.uiScale);font.bold:true
        }
    }
    handle:Item {implicitWidth:1;implicitHeight:1}
}
