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
        const referenceSeconds = settings.elementsLayout?.[0]?.referenceSeconds ?? settings.showSeconds
        return Qt.formatDateTime(now, (settings.use24Hour ? "HH:mm" : "hh:mm")
            + (referenceSeconds ? ":ss" : "") + (settings.use24Hour ? "" : " AP"))
    }

    function hours() {
        const hours = now.getHours()
        const value = settings.use24Hour ? hours : hours % 12 || 12
        return String(value).padStart(2, "0")
    }

    function initializeElements() {
        if (!editingOnScreen || settings.elementsLayout) return
        const titleX = item => item.effectiveHorizontalAlignment === Text.AlignLeft ? 0
            : item.effectiveHorizontalAlignment === Text.AlignRight ? item.width - item.contentWidth
            : (item.width - item.contentWidth) / 2
        const item = (x, y, label) => ({
            x: Math.round(x), y: Math.round(y), family: label.font.family, size: label.font.pixelSize,
            fill: String(label.fillColor), outline: String(label.outlineInk),
            stroke: label.outlined ? label.strokeWidth : 0
        })
        const x = timeRow.x
        const y = legacy.y + timeRow.y
        settings.elementsData = JSON.stringify([
            Object.assign(item(x, y, legacyTime), {referenceSeconds:settings.showSeconds}),
            item(x + beforeMinutes.advanceWidth, y, legacyTime),
            item(x + beforeSeconds.advanceWidth, y, legacyTime),
            item(titleX(firstTitle), legacy.y + firstTitle.y, firstTitle),
            item(titleX(secondTitle), legacy.y + secondTitle.y, secondTitle)
        ])
    }

    Connections {
        target: clock.settings
        function onEnableFreeLayout() { clock.initializeElements() }
    }
    TextMetrics {
        id: beforeMinutes
        font: legacyTime.font
        text: clock.hours() + ":"
    }
    TextMetrics {
        id: beforeSeconds
        font: legacyTime.font
        text: clock.hours() + ":" + Qt.formatDateTime(clock.now, "mm:")
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
                id: legacy
                width: parent.width
                y: clock.settings.verticalAlignment === 1 ? (parent.height - height) / 2
                    : clock.settings.verticalAlignment === 2 ? parent.height - height : 0
                spacing: clock.settings.elementSpacing

                ClockOutlineText {
                    settings: clock.settings
                    width: parent.width
                    id: firstTitle
                    opacity: clock.settings.elementsLayout ? 0 : 1
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
                    id: secondTitle
                    opacity: clock.settings.elementsLayout ? 0 : 1
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
                    id: timeRow
                    x: clock.settings.horizontalAlignment === 0 ? 0 : clock.settings.horizontalAlignment === 2 ? parent.width - width : (parent.width - width) / 2
                    spacing: 8
                    ClockOutlineText {
                        settings: clock.settings
                        id: legacyTime
                        opacity: clock.settings.elementsLayout ? 0 : 1
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

            Repeater {
                model: clock.settings.elementNames.length
                delegate: ClockOutlineText {
                    id: element
                    required property int index
                    readonly property var configuration: clock.settings.elementsLayout?.[index]
                    settings: clock.settings
                    individual: true
                    x: configuration?.x ?? 0
                    y: configuration?.y ?? 0
                    fillColor: configuration?.fill ?? "white"
                    originalOutline: configuration?.outline ?? "transparent"
                    strokeWidth: configuration?.stroke ?? 0
                    font.family: configuration?.family || clock.settings.fontFamily
                    font.pixelSize: configuration?.size ?? 20
                    font.weight: clock.settings.fontWeight
                    font.letterSpacing: index === 3 ? 1.6 : index === 4 ? 6 : -2
                    visible: !!configuration && (index !== 2 || clock.settings.showSeconds)
                    text: index === 0 ? clock.hours() + ":"
                        : index === 1 ? Qt.formatDateTime(clock.now, "mm") + (clock.settings.showSeconds ? ":" : "")
                        : index === 2 ? Qt.formatDateTime(clock.now, "ss")
                        : index === 3 ? clock.settings.title : clock.settings.signature

                    MouseArea {
                        anchors.fill: parent
                        enabled: clock.pointerOnScreen
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        cursorShape: Qt.SizeAllCursor
                        property point start
                        property point origin
                        onPressed: event => {
                            start = mapToItem(face, event.x, event.y)
                            origin = Qt.point(element.x, element.y)
                            clock.settings.selectedElement = element.index
                        }
                        onPositionChanged: event => {
                            if (!pressed) return
                            const point = mapToItem(face, event.x, event.y)
                            clock.settings.editElement(element.index, {
                                x: Math.round(origin.x + point.x - start.x),
                                y: Math.round(origin.y + point.y - start.y)
                            })
                        }
                    }
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
