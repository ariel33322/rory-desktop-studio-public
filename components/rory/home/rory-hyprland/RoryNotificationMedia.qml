pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "RoryTheme.js" as Theme

Rectangle {
    id: card
    required property string theme
    readonly property var player: Mpris.players.values.find(item => item.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property real duration: player?.lengthSupported ? player.length : NaN
    readonly property real elapsed: player?.positionSupported ? player.position : NaN
    readonly property color accent: Theme.tone(theme, "#e45876", "#FF5B9A")
    readonly property color ink: Theme.tone(theme, "#fff1f5", "#F7C7DA")
    function timecode(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) return ""
        const whole = Math.floor(seconds)
        return Math.floor(whole / 60) + ":" + String(whole % 60).padStart(2, "0")
    }

    implicitHeight: content.implicitHeight + 20
    radius: 14
    color: Theme.tone(theme, "#22151c", "#25101E")
    border.color: Theme.tone(theme, "#743347", "#63324B")

    Timer {
        interval: 1000
        repeat: true
        running: card.visible && !!card.player?.isPlaying && !!card.player?.positionSupported
        onTriggered: card.player?.positionChanged()
    }

    component MediaButton: RoryButton {
        id: button
        required property string iconKind
        theme: card.theme
        flat: true
        tooltipEnabled: false
        Layout.preferredWidth: 36
        contentItem: Item {
            SakuraIcon { anchors.centerIn: parent; width: 20; height: 20; kind: button.iconKind; usable: button.enabled; selected: button.hovered }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            CrimsonArtwork {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                player: card.player
                active: card.visible && !!player
                accent: card.accent
                theme: card.theme
            }
            ColumnLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: card.player?.trackTitle || (card.player ? card.player.identity : "Sin reproducción")
                    color: card.ink
                    textFormat: Text.PlainText
                    font.pixelSize: 16
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    visible: !!text
                    text: card.player?.trackArtist ?? ""
                    color: card.ink
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    opacity: .72
                }
            }
        }
        Slider {
            id: progress
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            visible: Number.isFinite(card.elapsed) && card.duration > 0
            from: 0
            to: visible ? card.duration : 1
            value: visible ? Math.min(card.elapsed, to) : 0
            enabled: card.player?.canSeek ?? false
            Accessible.name: "Posición de reproducción"
            onMoved: if (enabled) card.player.position = value
            background: Rectangle {
                x: progress.leftPadding
                y: (progress.height - height) / 2
                width: progress.availableWidth
                height: 5
                radius: 2.5
                color: "#4b283b"
                Rectangle { width: parent.width * progress.visualPosition; height: parent.height; radius: 2.5; color: card.accent }
            }
            handle: Item { implicitWidth: 1; implicitHeight: 1 }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !!(card.timecode(card.elapsed) || card.timecode(card.duration))
            Label { Layout.fillWidth: true; text: card.timecode(card.elapsed); color: card.ink }
            Label { text: card.timecode(card.duration); color: card.ink }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !!card.player
            MediaButton { iconKind: "previous"; hint: "Anterior"; enabled: card.player?.canGoPrevious ?? false; onClicked: card.player.previous() }
            MediaButton {
                iconKind: card.player?.isPlaying ? "pause" : "play"
                hint: card.player?.isPlaying ? "Pausar" : "Reproducir"
                enabled: card.player?.isPlaying ? card.player.canPause : (card.player?.canPlay ?? false)
                onClicked: if (card.player.isPlaying) card.player.pause(); else card.player.play()
            }
            MediaButton { iconKind: "next"; hint: "Siguiente"; enabled: card.player?.canGoNext ?? false; onClicked: card.player.next() }
        }
    }
}
