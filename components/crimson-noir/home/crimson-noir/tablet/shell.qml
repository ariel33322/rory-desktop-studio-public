//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
// import QtWebEngine

ShellRoot {
    FloatingWindow {
        id: tablet
        title: "Crimson Noir Tablet"
        implicitWidth: 1050
        implicitHeight: 680
        color: "#0b080c"
        visible: true

        property bool locked: false
        property bool webOpen: false
        property string webTitle: ""
        property int inactiveSeconds: 0
        property string songTitle: "Sin reproducción"
        property string songArtist: ""
        property string songArtwork: ""
        property string playbackStatus: "Stopped"
        property string clockValue: Qt.formatTime(new Date(), "hh:mm")
        property string dateValue: Qt.formatDate(new Date(), "dddd, d 'de' MMMM 'de' yyyy")

        function openWeb(address, name) {
            activity()
            webTitle = name
            webOpen = true
            browser.url = address
        }
        function goHome() {
            webOpen = false
            activity()
        }
        function activity() { if (!locked) inactiveSeconds = 0 }
        function unlock() { locked = false; inactiveSeconds = 0 }
        function refreshClock() {
            const now = new Date()
            clockValue = Qt.formatTime(now, "hh:mm")
            dateValue = Qt.formatDate(now, "dddd, d 'de' MMMM 'de' yyyy")
        }
        function mediaCommand(action) {
            mediaControl.command = ["playerctl", action]
            mediaControl.running = true
        }
        function openApp(command) {
            activity()
            launcher.command = command
            launcher.running = true
        }
        readonly property string iconsDir: Qt.resolvedUrl("icons/")

        Item {
            id: surface
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: tablet.visible = false
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#220c19" }
                    GradientStop { position: 0.55; color: "#110a12" }
                    GradientStop { position: 1; color: "#08070a" }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onPositionChanged: tablet.activity()
            }

            Item {
                anchors.fill: parent
                visible: !tablet.locked && !tablet.webOpen
                Column {
                    anchors.fill: parent
                    anchors.margins: 44
                    spacing: 14
                    Row {
                        width: parent.width
                        height: 60
                        Column {
                            spacing: 4
                            Text { text: "CRIMSON NOIR"; color: "#f2dfe7"; font.pixelSize: 29; font.bold: true; font.letterSpacing: 5 }
                            Text { text: "TABLET"; color: "#b46a83"; font.pixelSize: 12; font.letterSpacing: 6 }
                        }
                        Item { width: parent.width - 365; height: 1 }
                        Text {
                            text: tablet.clockValue
                            color: "#d9b9c7"
                            font.pixelSize: 26
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#593044" }
                    Text { text: "ENTRETENIMIENTO"; color: "#cb8ca3"; font.pixelSize: 14; font.bold: true; font.letterSpacing: 3; topPadding: 12 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 55
                        Repeater {
                            model: [
                                { title: "Videos", icon: "video.png", fallback: "▶", command: ["sh", "-c", 'xdg-open "$(xdg-user-dir VIDEOS)"'] },
                                { title: "Música", icon: "musica.png", fallback: "♫", command: ["sh", "-c", 'xdg-open "$(xdg-user-dir MUSIC)"'] },
                                { title: "YouTube", icon: "youtube.png", fallback: "▶", url: "https://www.youtube.com" },
                                { title: "YouTube Music", icon: "youtube music.png", fallback: "♫", url: "https://music.youtube.com" }
                            ]
                            delegate: AppTile { }
                        }
                    }
                    Text { text: "REDES SOCIALES"; color: "#cb8ca3"; font.pixelSize: 14; font.bold: true; font.letterSpacing: 3; topPadding: 28 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 55
                        Repeater {
                            model: [
                                { title: "Instagram", icon: "instagram.png", fallback: "I", url: "https://www.instagram.com" },
                                { title: "Pinterest", icon: "pinterest.png", fallback: "P", url: "https://www.pinterest.com" },
                                { title: "WhatsApp", icon: "whatsapp.png", fallback: "W", url: "https://web.whatsapp.com" },
                                { title: "Facebook", icon: "facebook.png", fallback: "F", url: "https://www.facebook.com" }
                            ]
                            delegate: AppTile { }
                        }
                    }
                    Item { height: 1; width: 1; Layout.fillHeight: true }
                    Row {
                        width: parent.width
                        spacing: 16
                        Rectangle {
                            width: 142; height: 40; radius: 20; color: "#351625"; border.color: "#784058"
                            Text { anchors.centerIn: parent; text: "Configuración"; color: "#eed6df"; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: tablet.openApp(["pavucontrol"]) }
                        }
                        Rectangle {
                            width: 132; height: 40; radius: 20; color: "#24121b"; border.color: "#583045"
                            Text { anchors.centerIn: parent; text: "Bloquear"; color: "#cda3b4"; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: tablet.locked = true }
                        }
                    }
                }
            }
            component AppTile: Item {
                required property var modelData
                width: 165; height: 145
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90; height: 90
                        Image {
                            anchors.fill: parent
                            source: Qt.resolvedUrl("icons/" + modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.fallback
                            color: "#df9db4"
                            font.pixelSize: 46
                            visible: parent.children[0].status !== Image.Ready
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.title
                        color: "#f3e1e8"
                        font.pixelSize: 15
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: {
                    if (modelData.url) tablet.openWeb(modelData.url, modelData.title)
                    else tablet.openApp(modelData.command)
                } }
            }
            // Navegador incrustado. Se mantiene vivo al regresar al inicio.
            Item {
                id: webSurface
                anchors.fill: parent
                visible: tablet.webOpen && !tablet.locked
                z: 2

                Rectangle { anchors.fill: parent; color: "#100b12" }

                Rectangle {
                    id: browserBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 54
                    color: "#1d101a"

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        spacing: 14
                        Text { text: "‹"; color: "#f2dfe7"; font.pixelSize: 32; width: 34
                            MouseArea { anchors.fill: parent; onClicked: {
                                tablet.activity()
                                if (browser.canGoBack) browser.goBack()
                                else tablet.goHome()
                            } }
                        }
                        Text { text: "⌂"; color: "#f2dfe7"; font.pixelSize: 29; width: 36
                            MouseArea { anchors.fill: parent; onClicked: tablet.goHome() }
                        }
                        Text { text: "↻"; color: "#f2dfe7"; font.pixelSize: 25; width: 34
                            MouseArea { anchors.fill: parent; onClicked: { tablet.activity(); browser.reload() } }
                        }
                        Text { text: tablet.webTitle; color: "#d9b9c7"; font.pixelSize: 16;
                            anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: tablet.clockValue; color: "#d9b9c7"; font.pixelSize: 16
                        anchors.right: parent.right; anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter }
                }

                Item {
                    id: browser
                    anchors.top: browserBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: bottomBar.top

                    property url url: "about:blank"

                    function reload() {}

                    Text {
                        anchors.centerIn: parent
                        text: "Navegador temporalmente desactivado"
                        color: "#d9b9c7"
                        font.pixelSize: 18
                    }
                }

                Rectangle {
                    id: bottomBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 42
                    color: "#1d101a"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 110; height: 5; radius: 3; color: "#d9b9c7"
                        MouseArea { anchors.fill: parent; anchors.margins: -15; onClicked: tablet.goHome() }
                    }
                }
            }

            Rectangle {
                id: lockScreen
                anchors.fill: parent
                color: "#0c0910"
                opacity: tablet.locked ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 0.86, 800)
                    height: Math.min(parent.height * 0.82, 510)
                    radius: 34
                    color: "#1b111b"
                    border.color: "#4d2438"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 50, 620)
                        spacing: 18
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tablet.clockValue
                            color: "#fff1f4"
                            font.pixelSize: 88
                            font.weight: Font.Light
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tablet.dateValue
                            color: "#c7aab5"
                            font.pixelSize: 19
                        }
                        Item { width: 1; height: 12 }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 18
                            Rectangle {
                                width: 100
                                height: 100
                                radius: 15
                                clip: true
                                color: "#422035"
                                Image {
                                    anchors.fill: parent
                                    source: tablet.songArtwork
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "♫"
                                    color: "#e5a1b7"
                                    font.pixelSize: 43
                                    visible: tablet.songArtwork === ""
                                }
                            }
                            Column {
                                width: Math.min(350, lockScreen.width * 0.42)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text {
                                    text: tablet.songTitle
                                    color: "#f8e9ef"
                                    font.pixelSize: 20
                                    font.bold: true
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: tablet.songArtist
                                    color: "#bda4ae"
                                    font.pixelSize: 15
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                Row {
                                    spacing: 12
                                    Repeater {
                                        model: [
                                            { label: "◀◀", action: "previous" },
                                            { label: tablet.playbackStatus === "Playing" ? "Ⅱ" : "▶", action: "play-pause" },
                                            { label: "▶▶", action: "next" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 48
                                            height: 40
                                            radius: 12
                                            color: "#53283d"
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: "#ffe8f0"
                                                font.pixelSize: 16
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: tablet.mediaCommand(modelData.action)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: 14 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Desliza hacia arriba para desbloquear"
                            color: "#a98c99"
                            font.pixelSize: 14
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 90
                            height: 5
                            radius: 3
                            color: "#c06a86"
                        }
                    }
                }

                // Se puede iniciar el gesto en cualquier punto libre de la pantalla.
                // Las coordenadas globales del ratón evitan perder el movimiento al salir del área.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    property real startY: 0
                    onPressed: (mouse) => startY = mouse.y
                    onReleased: (mouse) => {
                        if (startY - mouse.y > 65) tablet.unlock()
                    }
                }
                // Zona inferior amplia y alternativa por clic para evitar bloqueos durante pruebas.
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 120
                    property real startY: 0
                    onPressed: (mouse) => startY = mouse.y
                    onReleased: (mouse) => {
                        if (startY - mouse.y > 45) tablet.unlock()
                    }
                    onDoubleClicked: tablet.unlock()
                }
            }
        }
        Timer {
            interval: 1000; running: tablet.visible; repeat: true
            onTriggered: {
                tablet.refreshClock()
                if (!tablet.locked && !tablet.webOpen) {
                    tablet.inactiveSeconds++
                    if (tablet.inactiveSeconds >= 120) tablet.locked = true
                }
            }
        }
        Timer {
            interval: 2500; running: tablet.visible; repeat: true; triggeredOnStart: true
            onTriggered: { if (!mediaQuery.running) mediaQuery.running = true }
        }
        Process { id: launcher }
        Process {
            id: mediaQuery
            command: ["sh", "-c", "playerctl metadata --format '{{status}}\t{{title}}\t{{artist}}\t{{mpris:artUrl}}' 2>/dev/null || true"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = text.trim().split("\t")
                    tablet.playbackStatus = parts[0] || "Stopped"
                    tablet.songTitle = parts[1] || "Sin reproducción"
                    tablet.songArtist = parts[2] || ""
                    tablet.songArtwork = parts[3] || ""
                }
            }
        }
        Process { id: mediaControl; command: ["playerctl", "play-pause"] }
    }
}