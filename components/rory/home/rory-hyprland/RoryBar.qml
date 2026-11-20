pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland
import "RoryTheme.js" as Theme
import "SakuraDecoration.js" as Sakura

PanelWindow {
    id: bar
    required property ShellScreen modelData
    required property SystemState services
    required property WallpaperSettings wallpaperSettings
    property string theme:"crimson"
    property var sakuraConfig:Sakura.defaults()
    property var sakuraStudio:null
    property var notificationOptions: null
    property var notificationSource: null
    readonly property bool notificationPage: activePage === "notifications"
    onNotificationOptionsChanged: if (notificationPage && !(notificationOptions?.showIcon ?? true)) closePanel()
    Connections {
        target: bar.notificationOptions
        function onShowIconChanged() { if (!bar.notificationOptions.showIcon && bar.notificationPage) bar.closePanel() }
    }
    readonly property bool useSakura:theme==="sakura" && sakuraConfig.enabled
    readonly property real branchGrowth:requestedVisible
        ? (sakuraConfig.animation ? Math.min(sakuraMotion.unfold,Math.max(bodyProgress*.34,gardenProgress)) : Number(bodyProgress>0))
        : gardenProgress
    onUseSakuraChanged: if(!useSakura)sakuraMotion?.stop()
    onSakuraConfigChanged:if(!sakuraConfig.animation)sakuraMotion?.stop()
    Connections {
        target:bar.sakuraStudio
        function onSakuraPreviewRequested(output) {
            if(output===bar.modelData && bar.useSakura)bar.previewSakura()
        }
    }
    function previewSakura() {
        showBar(false)
        sakuraMotion.start()
        previewHold.interval=sakuraConfig.animation ? 1000+sakuraConfig.fall : 950
        previewHold.restart()
    }
    function petalOrigins() {
        const points=[]
        for(let index=0;index<10;index++) {
            for(const [branch,side] of [[leftSakura,-1],[rightSakura,1]]) {
                const point=branch.spawningPoint(index)
                const origin=branch.mapToItem(bar.contentItem,point.x,point.y)
                points.push({x:origin.x,y:origin.y,side:side})
            }
        }
        return points
    }
    function branchScale(item,drop) {
        const room=Math.max(0,decorationHeight-drop)
        return Math.max(0,Math.min(narrow ? .71*sakuraConfig.size : .88*sakuraConfig.size,
            width*.46/item.width,room/item.height))
    }
    SakuraMotion {id:sakuraMotion;config:bar.sakuraConfig;origins:()=>bar.petalOrigins()}
    Loader {
        active:bar.useSakura && sakuraMotion.particles.length>0
        Component.onCompleted:setSource("SakuraPetalLayer.qml",{output:Qt.binding(()=>bar.modelData),motion:sakuraMotion})
    }
    Timer {id:previewHold;onTriggered:bar.scheduleHide()}
    function tone(original,pink) {return Theme.tone(theme,original,pink)}
    property CrimsonCoordinator crimson: null
    property var crimsonConfig: null
    readonly property var crimsonOutput: modelData
    readonly property real crimsonAnchorY: Math.max(0,frame.y+frame.height)
    readonly property real crimsonRightInset: frame.x
    readonly property bool crimsonOnOutput: !!crimson?.visible && crimson.output===modelData
    onCrimsonOnOutputChanged: if(crimsonOnOutput)showBar(false);else scheduleHide()
    onCrimsonConfigChanged: if(!crimsonConfig?.enabled)crimson?.release(bar)
    Component.onDestruction: crimson?.release(bar)
    function openCrimson() {
        if(!crimsonConfig?.enabled || !crimson)return
        if(crimsonOnOutput)crimson.close()
        else crimson.openFor(bar)
    }


    function openCrimsonDetail(page) {
        const indicators={network:networkButton,bluetooth:bluetoothButton,audio:audioButton,battery:batteryButton}
        if(indicators[page])showPage(page,indicators[page])
    }

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: bodyHeight + 12 + decorationHeight
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
    readonly property int decorationHeight: Math.ceil(182 * vineScale)
    property real bodyProgress: 0
    property real gardenProgress: 0
    property bool requestedVisible: false
    readonly property bool pointerInBar: edgeHover.hovered || bodyHover.hovered
        || [networkButton, bluetoothButton, audioButton, batteryButton, notificationButton, powerButton]
            .some(button => button.hovered || button.pressed)

    onPointerInBarChanged: {
        if (pointerInBar) showBar()
        else scheduleHide()
    }

    function showBar(animate) {
        hideDelay.stop()
        if (requestedVisible && !conceal.running) return
        const fromHidden=bodyProgress<=.001
        requestedVisible = true
        conceal.stop()
        reveal.restart()
        if(useSakura && fromHidden && animate!==false)sakuraMotion.start()
    }

    function scheduleHide() {
        if (!pointerInBar && !controls.visible && !crimsonOnOutput && !previewHold.running) hideDelay.restart()
        else hideDelay.stop()
    }

    function hideBar() {
        if (controls.visible || crimsonOnOutput || previewHold.running) return
        sakuraMotion.stop()
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
            if (!bar.pointerInBar && !controls.visible && !bar.crimsonOnOutput) bar.hideBar()
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
        crimson?.close()
        if (services.panelOwner && services.panelOwner !== bar) services.panelOwner.closePanel()
        services.panelOwner = bar
        if (controls.visible && !panelClose.running && activePage === page) {
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
        border.color: bar.tone("#b1162e","#FF5B9A")
        gradient: Gradient {
            GradientStop { position: 0; color: bar.tone("#ea11090e","#EA120B14") }
            GradientStop { position: 0.5; color: bar.tone("#e80c090d","#E825101E") }
            GradientStop { position: 1; color: bar.tone("#f012090e","#F0120B14") }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 7
            color: "transparent"
            border.color: bar.tone("#810f25","#F02F7E")
        }

        Image {
            x: -12
            y: -6
            height: parent.height + 12
            width: height * 86 / 108
            source: Theme.art(bar.theme,"floral-corner")
            enabled: false
        }

        Image {
            anchors.right: parent.right
            anchors.rightMargin: -12
            y: -6
            height: parent.height + 12
            width: height * 86 / 108
            source: Theme.art(bar.theme,"floral-corner")
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
                                theme:bar.theme
                                required property var modelData
                                text: modelData.name
                                workspaceStyle: true
                                height: 28
                                width: Math.max(implicitWidth, 36)
                                textSize: 15
                                selected: modelData.active
                                hint: "Espacio " + modelData.name
                                ink: modelData.urgent ? bar.tone("#ff94ab","#FF9DC3") : bar.tone("#f4e8eb","#F7C7DA")
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    visible: bar.workspaces.length > 0 && bar.width >= 560
                    color: bar.tone("#532332","#873556")
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
                    color: bar.activeWindow ? bar.tone("#f4edef","#F7C7DA") : bar.tone("#a9949c","#C694AF")
                    textFormat: Text.PlainText
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            Image {
                id: identity
                objectName:"roryBarOrnament"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, Math.min(600, parent.width * 0.40,
                    parent.width - 2 * (statusRow.width + 12)))
                height: width * 126 / 1000
                y: (frame.height - height) / 2 + (bar.narrow ? 3 : 7)
                source: Theme.art(bar.theme,"floral-center")
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

                MouseArea {
                    x:statusRow.x+networkButton.x
                    y:statusRow.y
                    width:audioButton.x+audioButton.width-networkButton.x
                    height:statusRow.height
                    enabled:!!bar.crimsonConfig?.enabled && !!bar.crimson && !bar.crimsonOnOutput
                    acceptedButtons:Qt.LeftButton
                    onClicked:bar.openCrimson()
                }

                Row {
                    id: statusRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: bar.narrow ? 3 : 8

                    component StatusButton: RoryButton {
                        theme:bar.theme
                        flat: true
                        implicitWidth: 34
                        implicitHeight: 32
                        glyphSize: 21
                        glyphInk: glyphOff ? bar.tone("#88606b","#97637F") : bar.tone("#ff6676","#FF9DC3")
                    }

                    component SystemIndicator: StatusButton {
                        id: indicator
                        required property string page
                        opacity:bar.crimsonOnOutput ? 0 : 1
                        enabled:!bar.crimsonOnOutput
                        onClicked: {
                            if(bar.crimsonConfig?.enabled && bar.crimson)bar.openCrimson()
                            else bar.showPage(page,indicator)
                        }
                    }

                    SystemIndicator {
                        id: networkButton
                        page:"network"
                        glyph: bar.wiredConnection ? "ethernet" : "network"
                        glyphOff: !bar.networkConnected
                        hint: "Red: " + bar.services.networkLabel + (bar.crimsonConfig?.enabled ? " · Clic: Centro de control" : "")
                        selected: controls.visible && bar.activePage === "network"
                    }

                    SystemIndicator {
                        id: bluetoothButton
                        page:"bluetooth"
                        glyph: "bluetooth"
                        glyphOff: !bar.services.adapter?.enabled
                        glyphInk: glyphOff ? bar.tone("#88606b","#97637F")
                            : bar.services.bluetoothConnections.length ? bar.tone("#f0788b","#FF5B9A") : bar.tone("#e44e62","#F02F7E")
                        hint: bar.services.bluetoothLabel + (bar.crimsonConfig?.enabled ? " · Clic: Centro de control" : "")
                        selected: controls.visible && bar.activePage === "bluetooth"
                    }

                    SystemIndicator {
                        id: audioButton
                        page:"audio"
                        objectName:"roryBarAudioIndicator"
                        glyph: "audio"
                        glyphLevel: bar.services.audio?.volume ?? 0
                        glyphOff: !bar.services.audio || bar.services.audio.muted
                        hint: (!bar.services.audio ? "Audio no disponible" : bar.services.audio.muted
                            ? "Volumen silenciado" : "Volumen " + Math.round(glyphLevel * 100) + " %") + (bar.crimsonConfig?.enabled ? " · Clic: Centro de control" : "")
                        selected: controls.visible && bar.activePage === "audio"
                    }

                    StatusButton {
                        id: batteryButton
                        objectName: "roryBarBatteryIndicator"
                        glyph: "battery"
                        glyphLevel: bar.services.charge / 100
                        glyphOff: bar.services.charge < 0
                        glyphCharging: bar.services.batteryState === "Cargando"
                        glyphInk: glyphOff ? bar.tone("#88606b","#97637F") : bar.services.charge <= 20 ? bar.tone("#f68e9e","#FFC3DD") : bar.tone("#ff6676","#FF9DC3")
                        hint: bar.services.batteryState + (bar.services.charge >= 0 ? ", " + bar.services.charge + " %" : "")
                        onClicked: bar.showPage("battery", batteryButton)
                        selected: controls.visible && bar.activePage === "battery"
                    }

                    StatusButton {
                        id: notificationButton
                        objectName: "roryBarNotificationIndicator"
                        visible: !!bar.notificationOptions && bar.notificationOptions.showIcon
                        selected: controls.visible && bar.notificationPage
                        tooltipEnabled: false
                        hint: bar.notificationOptions?.quiet ? "Notificaciones, No molestar activo" : "Notificaciones"
                        onClicked: bar.showPage("notifications", notificationButton)
                        contentItem: Item {
                            SakuraIcon {
                                anchors.centerIn: parent
                                width: 21; height: 21
                                kind: "dnd"
                                usable: !bar.notificationOptions?.quiet
                                selected: notificationButton.selected
                            }
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                x: parent.width / 2 + 6; y: parent.height / 2 - 10
                                color: bar.tone("#ff6676","#FF5B9A")
                                visible: !bar.notificationOptions?.quiet && (bar.notificationSource?.notifications.length ?? 0) > 0
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 27
                        anchors.verticalCenter: parent.verticalCenter
                        color: bar.tone("#a01a30","#F02F7E")
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(dateLabel.implicitWidth, timeLabel.implicitWidth) + (bar.narrow ? 6 : 25)
                        Text {
                            id: timeLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(bar.services.now, "HH:mm")
                            color: bar.tone("#f4e8eb","#F7C7DA")
                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }
                        Text {
                            id: dateLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: bar.locale.toString(bar.services.now, "ddd d MMM")
                            color: bar.tone("#c5aeb8","#E8A9C6")
                            font.pixelSize: 10
                        }
                    }

                    StatusButton {
                        id: powerButton
                        glyph: "power"
                        hint: "Menú de energía"
                        glyphInk: bar.tone("#ff566b","#FF5B9A")
                        selected: controls.visible && bar.activePage === "power"
                        onClicked: bar.showPage("power", powerButton)
                    }
                }
            }
        }
    }

    FloralVine {
        id: leftVine
        theme:bar.theme
        x: frame.x + 14
        y: frame.y + frame.height - 2
        growth: bar.useSakura ? 0 : bar.gardenProgress
        scale: bar.vineScale
        transformOrigin: Item.TopLeft
    }

    FloralVine {
        id: rightVine
        theme:bar.theme
        x: frame.x + frame.width - width - 14
        y: frame.y + frame.height - 2
        reflected: true
        growth: bar.useSakura ? 0 : Math.max(0, Math.min(1, (bar.gardenProgress - 0.10) / 0.90))
        scale: bar.vineScale
        transformOrigin: Item.TopRight
    }

    SakuraBranch {
        id:leftSakura
        rightBranch:false
        growth:bar.useSakura ? bar.branchGrowth : 0
        sway:sakuraMotion.shake*bar.sakuraConfig.shake*.92
        scale:bar.branchScale(leftSakura,bar.sakuraConfig.leftY)
        transformOrigin:Item.TopLeft
        x:Math.max(0,Math.min(bar.width*.5-width*scale,frame.x+14+bar.sakuraConfig.leftX))
        y:frame.y+frame.height+1+bar.sakuraConfig.leftY
        opacity:bar.sakuraConfig.opacity*Math.min(1,bar.bodyProgress*2)
    }
    SakuraBranch {
        id:rightSakura
        rightBranch:true
        growth:bar.useSakura ? bar.branchGrowth : 0
        sway:-sakuraMotion.shake*bar.sakuraConfig.shake*.65
        scale:bar.branchScale(rightSakura,bar.sakuraConfig.rightY)
        transformOrigin:Item.TopRight
        x:Math.min(bar.width,Math.max(bar.width*.5+width*scale,frame.x+frame.width-14+bar.sakuraConfig.rightX))-width
        y:frame.y+frame.height+1+bar.sakuraConfig.rightY
        opacity:bar.sakuraConfig.opacity*Math.min(1,bar.bodyProgress*2)
    }

    function panelDuration(opening) {
        if (!notificationPage) return opening ? 170 : 140
        if (notificationOptions?.animate === false) return 0
        return Math.min(500,Math.max(0,opening ? (notificationOptions?.openMs ?? 170) : (notificationOptions?.closeMs ?? 140)))
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
        target: bar; property: "panelProgress"; to: 1; duration: bar.panelDuration(true); easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: panelClose
        NumberAnimation { target: bar; property: "panelProgress"; to: 0; duration: bar.panelDuration(false); easing.type: Easing.InCubic }
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
            return Math.round(Math.max(8,Math.min(bar.width-implicitWidth-8,bar.width-point.x-(bar.notificationPage ? (bar.notificationOptions?.offset ?? 0) : 0))))
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
        mask: Region { x: 0; y: Math.max(0,controlCard.y); width: controlCard.width; height: panelClose.running ? 0 : Math.max(0,controlCard.height+Math.min(0,controlCard.y)) }
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
                maximumHeight: bar.notificationPage || bar.activePage === "battery"
                    ? Math.min(bar.notificationPage ? (bar.notificationOptions?.maxHeight ?? 650) : 740,
                        Math.max(1,(bar.modelData?.height ?? bar.height) - Math.max(0,frame.y+frame.height) - 28))
                    : Math.max(160,(bar.modelData?.height ?? bar.height)-100)
                availablePanelWidth: Math.max(1,bar.width-16)
                theme: bar.theme
                notificationSource: bar.notificationSource
                notificationOptions: bar.notificationOptions
                page: controls.visible ? bar.activePage : ""
                services: bar.services
                wallpaperSettings: bar.wallpaperSettings
                onDismissed: bar.closePanel()
            }
        }
    }
}
