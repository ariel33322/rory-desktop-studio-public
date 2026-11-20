pragma ComponentBehavior: Bound
import QtQuick

Item {
    id:artwork
    implicitWidth:46
    implicitHeight:46
    required property var player
    required property bool active
    required property color accent
    property string theme:"crimson"
    readonly property string address: supported(player?.trackArtUrl)
    readonly property string trackTitle:player?.trackTitle ?? ""
    property string displayedAddress:""
    function supported(value) {
        const raw=String(value ?? "").trim()
        if(raw.startsWith("/"))
            return "file://"+raw.split("/").map(encodeURIComponent).join("/")
        if(/^(file:\/\/\/|https?:\/\/)/i.test(raw))
            return raw
        return ""
    }
    function update() {
        displayedAddress=""
        if(active && address)Qt.callLater(load)
    }
    function load(){displayedAddress=active ? address : ""}
    onAddressChanged:update()
    onPlayerChanged:update()
    onTrackTitleChanged:if(address.startsWith("file:"))update()
    onActiveChanged:update()
    Image {
        id:cover
        objectName:"crimsonCover"
        anchors.fill:parent
        source:artwork.displayedAddress
        sourceSize.width:112
        sourceSize.height:112
        fillMode:Image.PreserveAspectFit
        asynchronous:true
        cache:!artwork.displayedAddress.startsWith("file:")
        retainWhileLoading:false
        visible:status===Image.Ready && artwork.displayedAddress!==""
    }
    Rectangle {
        objectName:"crimsonCoverFallback"
        anchors.fill:parent
        visible:!cover.visible
        radius:10
        color:"#2d1925"
        SakuraIcon {visible:artwork.theme==="sakura";anchors.centerIn:parent;width:24;height:24;kind:"music"}
        RoryGlyph {
            visible:artwork.theme!=="sakura"
            anchors.centerIn:parent;width:24;height:24
            kind:"audio";ink:artwork.accent
        }
    }
}
