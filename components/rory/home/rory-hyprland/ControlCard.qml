pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card
    required property string page
    required property SystemState services
    required property WallpaperSettings wallpaperSettings
    property int maximumHeight: 740
    property real opening: 1
    signal dismissed()
    implicitWidth: page === "audio" || page === "battery" ? 374 : 338
    implicitHeight: Math.min(maximumHeight, 98 + ((loader.item as Item)?.implicitHeight ?? 0))
    radius: 12
    color: "#f30e0c10"
    border.color: "#a91836"
    border.width: 1
    clip: true

    function advanced(module) {
        dismissed()
        Quickshell.execDetached(["systemsettings", module])
    }
    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 9; color: "transparent"; border.color: "#652032"; enabled: false }
    Repeater {
        model: 4
        Image {
            required property int index
            x: index%2 ? card.width-width : 0
            y: index < 2 ? 0 : card.height-height
            width: 48; height: 48; source: "assets/floral-corner.svg"
            mirror: index%2 === 1
            rotation: index >= 2 ? 180 : 0
            opacity: card.opening; scale: 0.8+0.2*card.opening
            enabled: false
        }
    }
    Image { x: card.width-43; y: card.height-43; width: 35; height: 35; source: "assets/panel-rose.svg"; opacity: card.opening; scale: card.opening; enabled: false }
    Column {
        anchors.fill: parent; anchors.margins: 18; spacing: 8
        RowLayout {
            id: header
            width: parent.width; height: 32
            RoryGlyph { kind: card.page === "battery" ? "battery" : card.page === "network" ? "network" : card.page === "bluetooth" ? "bluetooth" : card.page === "audio" ? "audio" : card.page === "wallpaper" ? "wallpaper" : "power"; Layout.preferredWidth: 23; Layout.preferredHeight: 23; ink: "#ffdbe2" }
            Text {
                Layout.fillWidth: true
                text: ({network:"Wi-Fi",bluetooth:"Bluetooth",audio:"Audio",battery:"Batería",power:"Energía",wallpaper:"Fondo de pantalla"})[card.page] ?? ""
                color: "#fff2f4"; font.pixelSize: 21; font.family: "Liberation Serif"
            }
            RoryButton { text: "×"; hint: "Cerrar controles"; onClicked: card.dismissed() }
        }
        PanelRule { height: 9 }
        ScrollView {
            id: scroll
            width: parent.width
            height: Math.max(0,card.height-98)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Loader {
                id: loader
                width: parent.width
                sourceComponent: ({network:networkPage,bluetooth:bluetoothPage,audio:audioPage,battery:batteryPage,power:powerPage,wallpaper:wallpaperPage})[card.page] ?? null
            }
        }
    }
    onPageChanged: scroll.ScrollBar.vertical.position = 0
    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onRevealTop() { scroll.ScrollBar.vertical.position = 0 }
    }
    Component { id: networkPage; NetworkPanel { services: card.services; onAdvanced: card.advanced("kcm_networkmanagement") } }
    Component { id: bluetoothPage; BluetoothPanel { services: card.services; onAdvanced: card.advanced("kcm_bluetooth") } }
    Component { id: audioPage; AudioPanel { services: card.services; onAdvanced: card.advanced("kcm_pulseaudio") } }
    Component { id: batteryPage; BatteryPanel { services: card.services; onAdvanced: card.advanced("kcm_powerdevilprofilesconfig") } }
    Component { id: powerPage; PowerPanel { onDismissed: card.dismissed() } }
    Component { id: wallpaperPage; WallpaperPanel { settings: card.wallpaperSettings } }
}
