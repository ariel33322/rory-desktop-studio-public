pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property ShellScreen modelData
    required property SystemState services
    required property WallpaperSettings wallpaperSettings

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: bodyHeight + 12 + Math.ceil(182 * vineScale)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "rory-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controls.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        width: bar.width
        height: 2
        Region {
            x: frame.x
            y: 0
            width: frame.width
            height: Math.max(0, Math.ceil(frame.y + frame.height))
        }
    }

    readonly property int bodyHeight: narrow ? 40 : 44
    readonly property real vineScale: narrow ? 0.55 : 0.72
    property real bodyProgress: 0
    property real gardenProgress: 0
    property bool requestedVisible: false
    readonly property bool pointerInBar: edgeHover.hovered || bodyHover.hovered
        || [networkButton, bluetoothButton, audioButton, batteryButton, powerButton]
            .some(button => button.hovered || button.pressed)

    onPointerInBarChanged: {
        if (pointerInBar) showBar()
        else scheduleHide()
    }

    function showBar() {
        hideDelay.stop()
        if (requestedVisible && !conceal.running) return
        requestedVisible = true
        conceal.stop()
        reveal.restart()
    }

    function scheduleHide() {
        if (!pointerInBar && !controls.visible) hideDelay.restart()
        else hideDelay.stop()
    }

    function hideBar() {
        if (controls.visible) return
        requestedVisible = false
        reveal.stop()
        conceal.restart()
    }

    HoverHandler {
        id: edgeHover
        parent: edgeSensor
        blocking: false
    }

    Item {
        id: edgeSensor
        width: bar.width
        height: 2
    }

    Timer {
        id: hideDelay
        interval: 380
        onTriggered: {
            if (!bar.pointerInBar && !controls.visible) bar.hideBar()
        }
    }

    ParallelAnimation {
        id: reveal
        NumberAnimation {
            target: bar
            property: "bodyProgress"
            to: 1
            duration: 210
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: 85 }
            NumberAnimation {
                target: bar
                property: "gardenProgress"
                to: 1
                duration: 390
                easing.type: Easing.InOutSine
            }
        }
    }

    SequentialAnimation {
        id: conceal
        NumberAnimation {
            target: bar
            property: "gardenProgress"
            to: 0
            duration: 250
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: bar
            property: "bodyProgress"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
    }

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0 && monitor && workspace.monitor?.id === monitor.id)
        .sort((a, b) => a.id - b.id)
    readonly property bool narrow: width < 850
    readonly property var activeWindow: monitor === Hyprland.focusedMonitor ? Hyprland.activeToplevel : null
    readonly property bool networkConnected: services.interfaces.some(device => device.connected)
    readonly property bool wiredConnection: services.interfaces.some(device => device.connected && device.type === DeviceType.Wired)
    readonly property string windowIcon: {
        const info = activeWindow?.lastIpcObject
        const appId = activeWindow?.wayland?.appId || info?.class || info?.initialClass
        const icon = appId ? DesktopEntries.heuristicLookup(appId)?.icon || appId : ""
        if (icon.startsWith("/")) return "file://" + icon.split("/").map(encodeURIComponent).join("/")
        return Quickshell.iconPath(icon, true) || Quickshell.iconPath("application-x-executable", true)
    }
    readonly property var locale: Qt.locale("es_MX")
    property string activePage: ""
    property Item popupAnchor: null

    function showPage(page, item) {
        if (services.panelOwner && services.panelOwner !== bar) services.panelOwner.closePanel()
        services.panelOwner = bar
        if (controls.visible && activePage === page) {
            closePanel()
            return
        }
        showBar()
        popupAnchor = item
        activePage = page
        panelClose.stop()
        if (!controls.visible) { controls.visible = true; panelProgress = 0 }
        panelOpen.restart()
        Qt.callLater(() => { if (controls.backingWindowVisible) { panelGrab.active = true; panelFocus.forceActiveFocus() } })
    }

    Rectangle {
        id: frame
        x: bar.narrow ? 14 : 24
        y: -height - 4 + (height + 14) * bar.bodyProgress
        width: bar.width - 2 * x
        height: bar.bodyHeight
        visible: bar.bodyProgress > 0

        HoverHandler {
            id: bodyHover
            margin: 10
            blocking: false
            enabled: bar.bodyProgress > 0
        }
        radius: 10
        border.color: "#b1162e"
        gradient: Gradient {
            GradientStop { position: 0; color: "#ea11090e" }
            GradientStop { position: 0.5; color: "#e80c090d" }
            GradientStop { position: 1; color: "#f012090e" }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 7
            color: "transparent"
            border.color: "#810f25"
        }

        Image {
            x: -12
            y: -6
            height: parent.height + 12
            width: height * 86 / 108
            source: "assets/floral-corner.svg"
            enabled: false
        }

        Image {
            anchors.right: parent.right
            anchors.rightMargin: -12
            y: -6
            height: parent.height + 12
            width: height * 86 / 108
            source: "assets/floral-corner.svg"
            mirror: true
            enabled: false
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: bar.narrow ? 30 : 42
            anchors.rightMargin: anchors.leftMargin
            enabled: bar.bodyProgress >= 0.99 && bar.requestedVisible

            RowLayout {
                anchors.left: parent.left
                anchors.right: identity.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Flickable {
                    id: workspaceStrip
                    Layout.preferredWidth: Math.min(parent.width, workspaceRow.width)
                    Layout.maximumWidth: Math.max(50, Math.min(280, bar.width * 0.24))
                    Layout.minimumWidth: Math.min(workspaceRow.width, 44)
                    Layout.preferredHeight: 28
                    contentWidth: workspaceRow.width
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentWidth > width
                    clip: true

                    Row {
                        id: workspaceRow
                        spacing: 7
                        Repeater {
                            model: bar.workspaces
                            RoryButton {
                                required property var modelData
                                text: modelData.name
                                workspaceStyle: true
                                height: 28
                                width: Math.max(implicitWidth, 36)
                                textSize: 15
                                selected: modelData.active
                                hint: "Espacio " + modelData.name
                                ink: modelData.urgent ? "#ff94ab" : "#f4e8eb"
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    visible: bar.workspaces.length > 0 && bar.width >= 560
                    color: "#532332"
                }

                Image {
                    id: activeIcon
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    visible: !!bar.activeWindow && bar.width >= 560 && status === Image.Ready
                    source: bar.activeWindow ? bar.windowIcon : ""
                    sourceSize.width: 24
                    sourceSize.height: 24
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: !bar.monitor?.activeWorkspace && !bar.workspaces.length ? "Espacios no disponibles"
                        : bar.activeWindow?.title || "Escritorio"
                    color: bar.activeWindow ? "#f4edef" : "#a9949c"
                    textFormat: Text.PlainText
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            Image {
                id: identity
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, Math.min(600, parent.width * 0.40,
                    parent.width - 2 * (statusRow.width + 12)))
                height: width * 126 / 1000
                y: (frame.height - height) / 2 + (bar.narrow ? 3 : 7)
                source: "assets/floral-center.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.max(1, Math.ceil(width))
                visible: width >= 54
                enabled: false
            }

            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: statusRow.width
                height: statusRow.height

                Row {
                    id: statusRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: bar.narrow ? 3 : 8

                    component StatusButton: RoryButton {
                        flat: true
                        implicitWidth: 34
                        implicitHeight: 32
                        glyphSize: 21
                        glyphInk: glyphOff ? "#88606b" : "#ff6676"
                    }

                    StatusButton {
                        id: networkButton
                        glyph: bar.wiredConnection ? "ethernet" : "network"
                        glyphOff: !bar.networkConnected
                        hint: "Red: " + bar.services.networkLabel
                        selected: controls.visible && bar.activePage === "network"
                        onClicked: bar.showPage("network", networkButton)
                    }

                    StatusButton {
                        id: bluetoothButton
                        glyph: "bluetooth"
                        glyphOff: !bar.services.adapter?.enabled
                        glyphInk: glyphOff ? "#88606b"
                            : bar.services.bluetoothConnections.length ? "#f0788b" : "#e44e62"
                        hint: bar.services.bluetoothLabel
                        selected: controls.visible && bar.activePage === "bluetooth"
                        onClicked: bar.showPage("bluetooth", bluetoothButton)
                    }

                    StatusButton {
                        id: audioButton
                        glyph: "audio"
                        glyphLevel: bar.services.audio?.volume ?? 0
                        glyphOff: !bar.services.audio || bar.services.audio.muted
                        hint: !bar.services.audio ? "Audio no disponible" : bar.services.audio.muted
                            ? "Volumen silenciado" : "Volumen " + Math.round(glyphLevel * 100) + " %"
                        selected: controls.visible && bar.activePage === "audio"
                        onClicked: bar.showPage("audio", audioButton)
                    }

                    StatusButton {
                        id: batteryButton
                        glyph: "battery"
                        glyphLevel: bar.services.charge / 100
                        glyphOff: bar.services.charge < 0
                        glyphCharging: bar.services.batteryState === "Cargando"
                        glyphInk: glyphOff ? "#88606b" : bar.services.charge <= 20 ? "#f68e9e" : "#ff6676"
                        hint: bar.services.batteryState + (bar.services.charge >= 0 ? ", " + bar.services.charge + " %" : "")
                        selected: controls.visible && bar.activePage === "battery"
                        onClicked: bar.showPage("battery", batteryButton)
                    }

                    StatusButton {
                        id: wallpaperButton
                        glyph: "wallpaper"
                        text: "Studio"
                        implicitWidth: 80
                        hint: "Abrir Rory Desktop Studio"
                        onClicked: {
                            bar.closePanel()
                            bar.wallpaperSettings.studioController.home(bar.modelData)
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 27
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#a01a30"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(dateLabel.implicitWidth, timeLabel.implicitWidth) + (bar.narrow ? 6 : 25)
                        Text {
                            id: timeLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(bar.services.now, "HH:mm")
                            color: "#f4e8eb"
                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }
                        Text {
                            id: dateLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: bar.locale.toString(bar.services.now, "ddd d MMM")
                            color: "#c5aeb8"
                            font.pixelSize: 10
                        }
                    }

                    StatusButton {
                        id: powerButton
                        glyph: "power"
                        hint: "Menú de energía"
                        glyphInk: "#ff566b"
                        selected: controls.visible && bar.activePage === "power"
                        onClicked: bar.showPage("power", powerButton)
                    }
                }
            }
        }
    }

    FloralVine {
        id: leftVine
        x: frame.x + 14
        y: frame.y + frame.height - 2
        growth: bar.gardenProgress
        scale: bar.vineScale
        transformOrigin: Item.TopLeft
    }

    FloralVine {
        id: rightVine
        x: frame.x + frame.width - width - 14
        y: frame.y + frame.height - 2
        reflected: true
        growth: Math.max(0, Math.min(1, (bar.gardenProgress - 0.10) / 0.90))
        scale: bar.vineScale
        transformOrigin: Item.TopRight
    }

    property real panelProgress: 0
    function closePanel() {
        if (!controls.visible || panelClose.running) return
        panelOpen.stop()
        panelGrab.active = false
        panelClose.restart()
    }
    NumberAnimation {
        id: panelOpen
        target: bar; property: "panelProgress"; to: 1; duration: 170; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: panelClose
        NumberAnimation { target: bar; property: "panelProgress"; to: 0; duration: 140; easing.type: Easing.InCubic }
        ScriptAction { script: controls.visible = false }
    }
    HyprlandFocusGrab {
        id: panelGrab
        windows: [bar, controls]
        onCleared: bar.closePanel()
    }
    PanelWindow {
        id: controls
        visible: false
        screen: bar.screen
        anchors { top: true; right: true }
        exclusiveZone: 0
        WlrLayershell.namespace: "rory-controls"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        margins.top: Math.max(0, Math.round(frame.y + frame.height + 9))
        margins.right: {
            if (!bar.popupAnchor) return 8
            const point = bar.popupAnchor.mapToItem(bar.contentItem, bar.popupAnchor.width, 0)
            return Math.round(Math.max(8,Math.min(bar.width-implicitWidth-8,bar.width-point.x)))
        }
        onVisibleChanged: {
            if (visible) bar.showBar()
            else { panelGrab.active = false; bar.scheduleHide() }
        }
        onBackingWindowVisibleChanged: {
            if (backingWindowVisible) Qt.callLater(() => {
                if (controls.visible && !panelClose.running) { panelGrab.active = true; panelFocus.forceActiveFocus() }
            })
        }
        mask: Region { x: 0; y: Math.max(0,controlCard.y); width: controlCard.width; height: controlCard.height }
        implicitWidth: controlCard.implicitWidth
        implicitHeight: controlCard.implicitHeight + 8
        color: "transparent"

        FocusScope {
            id: panelFocus
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: event => { event.accepted = true; bar.closePanel() }
            Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: controls.visible; onActivated: bar.closePanel() }
            ControlCard {
                id: controlCard
                width: parent.width
                height: implicitHeight
                y: -8 * (1-bar.panelProgress)
                opacity: bar.panelProgress
                opening: bar.panelProgress
                maximumHeight: Math.max(160,bar.screen.height-100)
                page: controls.visible ? bar.activePage : ""
                services: bar.services
                wallpaperSettings: bar.wallpaperSettings
                onDismissed: bar.closePanel()
            }
        }
    }
}
