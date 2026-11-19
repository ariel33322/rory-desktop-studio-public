pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: clock
    required property ShellScreen modelData
    required property ClockSettings settings
    required property WindowCoverage windowCoverage

    property bool displayEnabled:true
    property bool externalWallpaper: false
    screen: modelData
    objectName: "desktopClock"
    readonly property bool editingOnScreen: settings.editorScreen === modelData
    readonly property bool pointerOnScreen: editingOnScreen && settings.pointerEditMode
    readonly property string monitorName: Hyprland.monitorFor(modelData)?.name ?? ""
    visible: pointerOnScreen || (displayEnabled && ((editingOnScreen && settings.editorOpen) || !windowCoverage.isCovered(monitorName, "clock")))
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "rory-clock"
    WlrLayershell.layer: externalWallpaper ? WlrLayer.Bottom : WlrLayer.Background
    mask: Region {
        x: clock.pointerOnScreen ? face.x : clock.hitBounds.x
        y: clock.pointerOnScreen ? face.y : clock.hitBounds.y
        width: clock.pointerOnScreen ? face.width : clock.hitBounds.width
        height: clock.pointerOnScreen ? face.height : clock.hitBounds.height
    }

    property date now: new Date()
    readonly property real rotatedWidth: Math.abs(Math.cos(settings.clockRotation * Math.PI / 180)) * face.width + Math.abs(Math.sin(settings.clockRotation * Math.PI / 180)) * face.height
    readonly property real rotatedHeight: Math.abs(Math.sin(settings.clockRotation * Math.PI / 180)) * face.width + Math.abs(Math.cos(settings.clockRotation * Math.PI / 180)) * face.height
    readonly property rect hitBounds: Qt.rect(face.x - Math.max(0, rotatedWidth - face.width) / 2,
        face.y - Math.max(0, rotatedHeight - face.height) / 2,
        Math.max(face.width, rotatedWidth), Math.max(face.height, rotatedHeight))

    function dateLabel() {
        let formatted = Qt.locale("es_MX").toString(now, "dddd, d 'de' MMMM")
        return formatted.length ? formatted.charAt(0).toLocaleUpperCase() + formatted.slice(1) : formatted
    }
    function timeLabel() {
        return Qt.formatDateTime(now, (settings.use24Hour ? "HH:mm" : "hh:mm") + (settings.showSeconds ? ":ss" : "") + (settings.use24Hour ? "" : " AP"))
    }

    Timer {
        interval: 1000
        running: clock.visible
        triggeredOnStart: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    Item {
        id: viewport
        anchors.fill: parent

        ClockBackground {
            id: background
            settings: clock.settings
            x: face.x + clock.settings.backgroundX
            y: face.y + clock.settings.backgroundY
            width: clock.settings.backgroundWidth || face.width
            height: clock.settings.backgroundHeight || face.height
        }

        Item {
            id: face
            x: Math.min(clock.modelData.width * clock.settings.leftPercent,
                Math.max(0, clock.modelData.width - width))
            y: Math.min(clock.modelData.height * clock.settings.topPercent,
                Math.max(0, clock.modelData.height - height))
            width: clock.settings.widgetWidth
            height: clock.settings.widgetHeight
            clip: true
            rotation: clock.settings.clockRotation
            opacity: clock.settings.widgetOpacity

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: event => {
                    if (event.button === Qt.RightButton) {
                        clock.settings.pointerEditMode = false
                        clock.settings.editorScreen = clock.modelData
                        clock.settings.editorOpen = true
                    }
                }
            }

            Column {
                width: parent.width
                y: clock.settings.verticalAlignment === 1 ? (parent.height - height) / 2
                    : clock.settings.verticalAlignment === 2 ? parent.height - height : 0
                spacing: clock.settings.elementSpacing

                ClockOutlineText {
                    settings: clock.settings
                    width: parent.width
                    text: clock.settings.title
                    fillColor: clock.settings.accent
                    horizontalAlignment: clock.settings.horizontalAlignment === 0 ? Text.AlignLeft : clock.settings.horizontalAlignment === 2 ? Text.AlignRight : Text.AlignHCenter
                    font.family: clock.settings.fontFamily
                    font.weight: clock.settings.fontWeight
                    font.pixelSize: 20
                    font.letterSpacing: 1.6
                    originalOutline: "#baff174d"
                }

                ClockOutlineText {
                    settings: clock.settings
                    width: parent.width
                    text: clock.settings.signature
                    fillColor: clock.settings.textColor
                    horizontalAlignment: clock.settings.horizontalAlignment === 0 ? Text.AlignLeft : clock.settings.horizontalAlignment === 2 ? Text.AlignRight : Text.AlignHCenter
                    font.family: clock.settings.fontFamily
                    font.weight: clock.settings.fontWeight
                    font.pixelSize: 12
                    font.letterSpacing: 6
                    originalOutline: "#55ffffff"
                }

                Rectangle {
                    x: clock.settings.horizontalAlignment === 0 ? 0 : clock.settings.horizontalAlignment === 2 ? parent.width - width : (parent.width - width) / 2
                    width: Math.min(150, parent.width * 0.48)
                    height: 2
                    radius: 1
                    color: clock.settings.accent
                    opacity: 0.9
                }

                Row {
                    x: clock.settings.horizontalAlignment === 0 ? 0 : clock.settings.horizontalAlignment === 2 ? parent.width - width : (parent.width - width) / 2
                    spacing: 8
                    ClockOutlineText {
                        settings: clock.settings
                        text: clock.timeLabel().replace(/\s?(AM|PM)$/, "")
                        fillColor: clock.settings.textColor
                        font.family: clock.settings.fontFamily
                    font.weight: clock.settings.fontWeight
                        font.pixelSize: clock.settings.timeSize
                        font.letterSpacing: -2
                        originalOutline: "#66ffffff"
                    }
                    ClockOutlineText {
                        settings: clock.settings
                        anchors { bottom: parent.bottom; bottomMargin: 10 }
                        visible: !clock.settings.use24Hour
                        text: Qt.formatDateTime(clock.now, "AP")
                        fillColor: clock.settings.accent
                        font.family: clock.settings.fontFamily
                    font.weight: clock.settings.fontWeight
                        font.pixelSize: Math.round(clock.settings.timeSize * 0.34)
                        originalOutline: "#baff174d"
                    }
                }

                ClockOutlineText {
                    settings: clock.settings
                    width: parent.width
                    text: clock.dateLabel()
                    visible: clock.settings.showDate
                    fillColor: clock.settings.textColor
                    horizontalAlignment: clock.settings.horizontalAlignment === 0 ? Text.AlignLeft : clock.settings.horizontalAlignment === 2 ? Text.AlignRight : Text.AlignHCenter
                    font.family: clock.settings.fontFamily
                    font.weight: clock.settings.fontWeight
                    font.pixelSize: 16
                    font.letterSpacing: 2
                    originalOutline: "#55ffffff"
                }

                Row {
                    x: clock.settings.horizontalAlignment === 0 ? 0 : clock.settings.horizontalAlignment === 2 ? parent.width - width : (parent.width - width) / 2
                    spacing: 12
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 84; height: 1; color: clock.settings.accent }
                    Text { text: "❧"; color: clock.settings.accent; font.pixelSize: 26; rotation: 90 }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 84; height: 1; color: clock.settings.accent }
                }
            }
        }

        MouseArea {
            x: face.x; y: face.y; width: face.width; height: face.height
            enabled: clock.pointerOnScreen
            acceptedButtons: Qt.RightButton
            onClicked: clock.settings.editorOpen = true
        }

        ClockPointerEdit {
            id: pointerEdit
            anchors.fill: parent
            screen: clock.modelData
            editing: clock.pointerOnScreen
            settings: clock.settings
            face: face
        }
    }
}
