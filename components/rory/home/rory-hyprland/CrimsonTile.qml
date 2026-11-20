pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "RoryTheme.js" as Theme

Button {
    id: tile
    required property var config
    required property string symbol
    property string sakuraKey:""
    readonly property bool sakura:config.theme==="sakura"
    property string iconKind:""
    property string detail: ""
    property bool selected: false
    property bool compact: false
    property bool banner: false
    property real uiScale:1
    Layout.fillWidth:!compact
    implicitWidth:compact ? 62 : 122
    implicitHeight:compact ? implicitWidth : Math.round((banner ? 52 : 60)*uiScale)
    hoverEnabled:true
    Accessible.name:text
    Accessible.description:detail
    readonly property bool drawIcon:["flash","bell","record","capture"].includes(iconKind)
    contentItem:Item {
        Text {
            anchors.centerIn:parent
            visible:tile.compact && !tile.sakura && !tile.drawIcon
            text:tile.symbol
            color:tile.enabled ? (tile.selected ? "#ffe5ed" : "#f6c9da") : "#9e8793"
            font.pixelSize:Math.round((tile.config.iconSize+2)*tile.uiScale)
        }
        Canvas {
            id: torchIcon
            anchors.centerIn:parent
            width:Math.round((tile.config.iconSize+4)*tile.uiScale);height:width
            visible:tile.compact && !tile.sakura && tile.drawIcon
            readonly property color ink:tile.enabled ? "#f6c9da" : "#9e8793"
            onInkChanged:requestPaint()
            Connections {target:tile;function onIconKindChanged(){torchIcon.requestPaint()}}
            onPaint:{
                const ctx=getContext("2d")
                ctx.reset()
                ctx.scale(width/24,height/24)
                ctx.fillStyle=ink
                ctx.strokeStyle=ink
                ctx.lineWidth=2
                ctx.lineJoin="round"
                ctx.lineCap="round"
                if(tile.iconKind==="record") {
                    ctx.beginPath();ctx.arc(12,12,8,0,Math.PI*2);ctx.stroke()
                    ctx.beginPath();ctx.arc(12,12,5,0,Math.PI*2);ctx.fill();return
                }
                if(tile.iconKind==="capture") {
                    ctx.beginPath()
                    ctx.moveTo(4,9);ctx.lineTo(4,4);ctx.lineTo(9,4)
                    ctx.moveTo(15,4);ctx.lineTo(20,4);ctx.lineTo(20,9)
                    ctx.moveTo(20,15);ctx.lineTo(20,20);ctx.lineTo(15,20)
                    ctx.moveTo(9,20);ctx.lineTo(4,20);ctx.lineTo(4,15)
                    ctx.stroke();return
                }
                if(tile.iconKind==="bell") {
                    ctx.beginPath();ctx.moveTo(4,17);ctx.lineTo(7,14);ctx.lineTo(7,9)
                    ctx.bezierCurveTo(7,3,17,3,17,9);ctx.lineTo(17,14);ctx.lineTo(20,17)
                    ctx.closePath();ctx.fill()
                    ctx.beginPath();ctx.arc(12,19,2,0,Math.PI);ctx.fill();return
                }
                ctx.beginPath()
                ctx.moveTo(5,3);ctx.lineTo(19,3);ctx.lineTo(19,6);ctx.lineTo(15,11)
                ctx.lineTo(15,21);ctx.lineTo(9,21);ctx.lineTo(9,11);ctx.lineTo(5,6)
                ctx.closePath();ctx.fill()
                ctx.fillStyle="#1d1119"
                ctx.fillRect(5,5,14,1)
                ctx.beginPath();ctx.arc(12,14,1.5,0,Math.PI*2);ctx.fill()
            }
        }
        SakuraIcon {
            visible:tile.compact && tile.sakura
            anchors.centerIn:parent
            width:Math.round((tile.config.iconSize+4)*tile.uiScale);height:width
            kind:tile.sakuraKey;selected:tile.selected;usable:tile.enabled
        }
        RowLayout {
            visible:!tile.compact
            anchors.fill:parent
            anchors.leftMargin:4
            anchors.rightMargin:3
            spacing:8
            SakuraIcon {
                visible:tile.sakura
                Layout.preferredWidth:Math.round((tile.config.iconSize+3)*tile.uiScale)
                Layout.preferredHeight:width
                kind:tile.sakuraKey;selected:tile.selected;usable:tile.enabled
            }
            RoryGlyph {
                visible:!tile.sakura && tile.iconKind!=="" && tile.iconKind!=="flash"
                Layout.preferredWidth:Math.round((tile.config.iconSize+2)*tile.uiScale)
                Layout.preferredHeight:width
                kind:tile.iconKind;ink:tile.selected ? tile.config.accent : "#f2b9cf"
                off:!tile.enabled
            }
            Text {
                visible:!tile.sakura && tile.iconKind===""
                text:tile.symbol
                color:tile.sakura ? (tile.selected ? "#522038" : tile.hovered && tile.enabled ? "#3B1B30" : Theme.plum)
            : tile.selected ?  tile.config.accent : "#f2b9cf"
                font.pixelSize:Math.round((tile.config.iconSize+2)*tile.uiScale)
            }
            ColumnLayout {
                Layout.fillWidth:true
                spacing:2
                Text {
                    Layout.fillWidth:true
                    elide:Text.ElideRight;textFormat:Text.PlainText
                    text:tile.text;color:Theme.tone(tile.config.theme,"#fff0f4",Theme.text)
                    font.pixelSize:Math.round(14*tile.uiScale);font.weight:Font.Medium
                }
                Text {
                    visible:tile.detail!==""
                    Layout.fillWidth:true
                    elide:Text.ElideRight;textFormat:Text.PlainText
                    text:tile.detail;color:Theme.tone(tile.config.theme,"#d8aebf","#D7A2BD");font.pixelSize:Math.round(11*tile.uiScale)
                }
            }
            SakuraIcon {
                visible:tile.banner && tile.sakura
                Layout.preferredWidth:19;Layout.preferredHeight:19
                kind:"back";rotation:180;usable:tile.enabled
            }
            Text {
                visible:tile.banner && !tile.sakura;text:"›";color:"#edb6cc"
                font.pixelSize:Math.round(24*tile.uiScale)
            }
        }
    }
    background:Rectangle {
        radius:tile.compact ? width/2 : Math.min(height/2,tile.config.radius+8)
        color:tile.selected ? "#29121e" : tile.down ? "#321c29" : tile.hovered && tile.enabled ? "#2d1927" : "#1d1119"
        border.color:tile.selected || tile.activeFocus ? tile.config.accent : tile.sakura ? "#704058" : tile.config.decorative ? "#762040" : "#372831"
        border.width:tile.selected ? 1.5 : 1
        Repeater {
            model:tile.compact && !tile.sakura && tile.config.decorative ? [false,true] : []
            delegate:Image {
                required property bool modelData
                width:9;height:9
                x:modelData ? tile.width-width/2 : -width/2
                y:(tile.height-height)/2
                source:"art/floral-leaf.svg"
                mirror:modelData
                fillMode:Image.PreserveAspectFit
            }
        }
        Image {
            anchors.right:parent.right;anchors.bottom:parent.bottom
            anchors.rightMargin:tile.banner ? 25 : 6
            anchors.bottomMargin:3
            width:tile.banner ? parent.width*.28 : 22
            height:tile.banner ? parent.height*.85 : 18
            visible:!tile.sakura && tile.config.decorative && !tile.compact
            source:tile.banner ? "art/panel-rose.svg" : "art/floral-leaf.svg"
            fillMode:Image.PreserveAspectFit
            opacity:tile.banner ? .22 : .55
        }
        Behavior on color { ColorAnimation { duration:tile.config.duration } }
    }
}
