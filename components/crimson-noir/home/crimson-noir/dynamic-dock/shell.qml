import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property var audioLevels: Array(14).fill(0)
    property string mediaPlayer: ""
    property string mediaTitle: "Sin reproducción"
    property string mediaArtist: ""
    property string mediaArtwork: ""
    property string mediaStatus: "Stopped"
    property bool mediaAvailable: false

    function updateMedia(data) {
        const lines = data.trim().split("\n")
        const available = lines[0] === "1"

        mediaAvailable = available
        mediaPlayer = available ? (lines[1] || "") : ""
        mediaStatus = available ? (lines[2] || "Stopped") : "Stopped"
        mediaTitle = available ? (lines[3] || "Sin título") : "Sin reproducción"
        mediaArtist = available ? (lines[4] || "") : ""
        mediaArtwork = available ? (lines[5] || "") : ""
    }

    function mediaAction(action) {
        if (!mediaAvailable || !mediaPlayer || mediaProcess.running)
            return

        mediaProcess.command = [
            "playerctl", "-p", mediaPlayer, action
        ]
        mediaProcess.running = true
    }


    PanelWindow {
        id: dock

        anchors {
            left: true
            right: true
            bottom: true
        }

        implicitHeight: 470
        exclusiveZone: 55
        color: "transparent"


        Canvas {
            id: unifiedBackground
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                const w = width
                const h = height

                ctx.clearRect(0, 0, w, h)

                const barTop = h - 54
                const bottom = h - 6
                const r = 15
                const expanded = musicModule.expanded
                const left = w - 500
                const top = h - 13 - 400

                ctx.beginPath()

                ctx.moveTo(r, barTop)

                if (expanded) {
                    ctx.lineTo(left, barTop)
                    ctx.lineTo(left, top + r)
                    ctx.quadraticCurveTo(left, top, left + r, top)
                    ctx.lineTo(w - r, top)
                    ctx.quadraticCurveTo(w, top, w, top + r)
                } else {
                    ctx.lineTo(w - r, barTop)
                    ctx.quadraticCurveTo(w, barTop, w, barTop + r)
                }

                ctx.lineTo(w, bottom - r)
                ctx.quadraticCurveTo(w, bottom, w - r, bottom)
                ctx.lineTo(r, bottom)
                ctx.quadraticCurveTo(0, bottom, 0, bottom - r)
                ctx.lineTo(0, barTop + r)
                ctx.quadraticCurveTo(0, barTop, r, barTop)

                ctx.closePath()

                ctx.fillStyle = "#E6121218"
                ctx.fill()

                ctx.strokeStyle = "#793043"
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }

        Rectangle {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6

            height: 48
            radius: 15
            color: "transparent"
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 7
                spacing: 7

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Item {
                    Layout.preferredWidth: 500
                    Layout.preferredHeight: 32
                }
            }
            TaskIcons {
                id: centeredTaskIcons

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                z: 10
            }
        }

        Rectangle {
            id: musicModule

            property bool expanded: false
            property int compactHeight: 32
            property int expandedHeight: 400

            onExpandedChanged: unifiedBackground.requestPaint()

            anchors.right: bar.right
            anchors.rightMargin: 0
            anchors.bottom: bar.bottom
            anchors.bottomMargin: 7

            width: 500
            height: expanded ? expandedHeight : compactHeight

            radius: 0
            color: "transparent"
            border.width: 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation { duration: 180 }
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        closePlayer.stop()
                        musicModule.expanded = true
                    } else {
                        closePlayer.restart()
                    }
                }
            }

            // Visualizador único que acompaña la contracción del módulo.
            Item {
                id: spectrumCarrier

                width: parent.width
                height: musicModule.expanded ? 175 : musicModule.compactHeight

                anchors.bottom: parent.bottom

                CrimsonWaves {
                    id: compactSpectrum
                    anchors.fill: parent
                    anchors.margins: musicModule.expanded ? 5 : 3
                    levels: root.audioLevels
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: expandedContent

                anchors.fill: parent
                anchors.margins: 12

                visible: musicModule.expanded
                opacity: musicModule.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }

                Column {
                    anchors.fill: parent
                    spacing: 10

                    Row {
                        id: infoRow

                        width: parent.width
                        height: 188
                        spacing: 15

                        Rectangle {
                            id: cover

                            width: 188
                            height: 188
                            radius: 12
                            color: "#391321"
                            clip: true

                            Image {
                                id: coverImage

                                anchors.fill: parent
                                source: root.mediaArtwork
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true

                                visible: root.mediaArtwork !== ""
                                         && status === Image.Ready
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 7
                                visible: !coverImage.visible

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "♫"
                                    color: "#FF647C"
                                    font.pixelSize: 60
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Crimson Noir"
                                    color: "#D69EAD"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Column {
                            width: infoRow.width - cover.width - infoRow.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Text {
                                width: parent.width
                                text: root.mediaTitle
                                color: "#FFFFFF"
                                font.pixelSize: 17
                                font.bold: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width

                                text: root.mediaArtist !== ""
                                    ? root.mediaArtist
                                    : root.mediaAvailable
                                        ? root.mediaPlayer.split(".")[0]
                                        : "Sin música activa"

                                color: "#E0A8B7"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.mediaStatus === "Playing"
                                    ? "● Reproduciendo"
                                    : root.mediaStatus === "Paused"
                                        ? "● Pausado"
                                        : "● Inactivo"

                                color: root.mediaStatus === "Playing"
                                    ? "#FF647C" : "#A58B96"

                                font.pixelSize: 11
                            }

                            Row {
                                spacing: 28

                                Text {
                                    text: "⏮"
                                    font.pixelSize: 25
                                    color: "#FFFFFF"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.mediaAction("previous")
                                    }
                                }

                                Text {
                                    text: root.mediaStatus === "Playing"
                                        ? "⏸" : "▶"

                                    font.pixelSize: 25
                                    color: "#FF647C"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.mediaAction("play-pause")
                                    }
                                }

                                Text {
                                    text: "⏭"
                                    font.pixelSize: 25
                                    color: "#FFFFFF"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.mediaAction("next")
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 175

                        // Las ondas se dibujan en spectrumCarrier.
                        // Se conserva este espacio para mantener el diseño.


                    }
                }
            }
        }

        Timer {
            id: closePlayer
            interval: 60
            repeat: false

            onTriggered: {
                musicModule.expanded = false
            }
        }
    }

    Process {
        id: mediaProcess
        running: false
    }

    Process {
        id: mediaInfoProcess

        command: [
            Quickshell.shellPath("media-info.sh")
        ]

        running: false

        stdout: StdioCollector {
            onStreamFinished: root.updateMedia(text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!mediaInfoProcess.running)
                mediaInfoProcess.running = true
        }
    }

    Process {
        id: cavaProcess

        command: [
            "cava", "-p",
            Quickshell.shellPath("cava.conf")
        ]

        running: true

        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split(";")
                    .filter(v => v.length > 0)
                    .map(v => Number(v))

                if (values.length >= 14)
                    root.audioLevels = values.slice(0, 14)
            }
        }
    }
}