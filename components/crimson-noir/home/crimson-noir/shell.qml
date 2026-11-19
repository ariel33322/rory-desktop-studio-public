pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    PanelWindow {
        id: phoneWindow

        anchors { bottom: true }
        implicitWidth: Math.min(760, screen?.width ?? 760)
        implicitHeight: Math.min(760, screen?.height ?? 760)
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        visible: false

        property bool drawerOpen: false
        property bool wallpaperOptionsOpen: false
        property string wallpaperTarget: ""
        property url wallpaperUrl: ""
        property url lockWallpaperUrl: ""
        property bool closing: false
        property bool reopenAfterClose: false
        property var contextApp: null
        property int contextHomeIndex: -1
        property var pendingApp: null
        property date now: new Date()
        readonly property real phoneScale: Math.min(1, width / 310, height / 620)
        readonly property var filteredApps: {
            const query = searchInput.text.trim().toLocaleLowerCase()
            return DesktopEntries.applications.values
                .filter(app => app.name.toLocaleLowerCase().includes(query))
                .sort((a, b) => a.name.localeCompare(b.name))
        }

        function fechaEspanol() {
            const days = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
            const months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
            const day = days[now.getDay()]
            return day[0].toUpperCase() + day.slice(1) + " " + now.getDate() + " de " + months[now.getMonth()]
        }

        function openDrawer() {
            if (closing || !phone.unlocked || !phone.lockDismissed) return
            drawerOpen = true
            searchInput.forceActiveFocus()
        }

        function closeDrawer() {
            drawerOpen = false
            searchInput.clear()
            homeFocus.forceActiveFocus()
        }

        function handleEscape() {
            if (wallpaperTarget) wallpaperTarget = ""
            else if (wallpaperOptionsOpen) wallpaperOptionsOpen = false
            else if (contextApp) contextApp = null
            else if (drawerOpen) closeDrawer()
            else closePhone(null)
        }

        function openPhone() {
            if (visible || closing) return
            phone.travel = 1
            phone.rotation = 180
            phone.opacity = 0
            phone.unlocked = false
            phone.lockDismissed = false
            lockScreen.progress = 0
            now = new Date()
            visible = true
            homeFocus.forceActiveFocus()
            openAnimation.start()
        }

        function togglePhone() {
            if (closing) reopenAfterClose = !reopenAfterClose
            else if (visible) closePhone(null)
            else openPhone()
        }

        function closePhone(app) {
            if (!visible || closing) return
            closing = true
            contextApp = null
            pendingApp = app
            focusGrab.active = false
            openAnimation.stop()
            unlockAnimation.stop()
            closeAnimation.start()
        }

        function finishClose() {
            const app = pendingApp
            const reopen = reopenAfterClose
            visible = false
            drawerOpen = false
            searchInput.clear()
            wallpaperOptionsOpen = false
            wallpaperTarget = ""
            noticeTimer.stop()
            noticeText.text = ""
            pendingApp = null
            reopenAfterClose = false
            closing = false
            if (app) app.execute()
            if (reopen) Qt.callLater(phoneWindow.openPhone)
        }

        function selectWallpaper(file) {
            const url = file.toString()
            if (!/^file:.*\.(png|jpe?g|webp)$/i.test(url)) return
            if (wallpaperTarget === "lock") {
                lockWallpaperUrl = file
                lockWallpaperSettings.setText(url)
            } else if (wallpaperTarget === "home") {
                wallpaperUrl = file
                wallpaperSettings.setText(url)
            }
            wallpaperTarget = ""
        }

        function launchShortcut(appId, label) {
            const app = DesktopEntries.byId(appId)
            if (app) closePhone(app)
            else showNotice(label + " no está disponible")
        }

        function showNotice(message) {
            noticeText.text = message
            noticeTimer.restart()
        }

        function shortcutAt(cell) {
            for (let i = 0; i < homeApps.count; ++i)
                if (homeApps.get(i).cell === cell) return i
            return -1
        }

        function addShortcut(app) {
            for (let i = 0; i < homeApps.count; ++i)
                if (homeApps.get(i).appId === app.id) return
            for (let cell = 0; cell < 12; ++cell) {
                if (shortcutAt(cell) !== -1) continue
                homeApps.append({appName: app.name, appId: app.id, iconFile: "", cell: cell})
                savePositions()
                return
            }
            showNotice("La pantalla principal está llena")
        }

        function moveShortcut(index, cell) {
            const previousCell = homeApps.get(index).cell
            if (previousCell === cell) return
            const occupied = shortcutAt(cell)
            if (occupied !== -1) homeApps.setProperty(occupied, "cell", previousCell)
            homeApps.setProperty(index, "cell", cell)
            savePositions()
        }

        function savePositions() {
            const shortcuts = []
            for (let i = 0; i < homeApps.count; ++i) {
                const app = homeApps.get(i)
                shortcuts.push({appName: app.appName, appId: app.appId,
                                iconFile: app.iconFile, cell: app.cell})
            }
            positions.setText(JSON.stringify(shortcuts))
        }

        function restorePositions() {
            const saved = positions.text()
            if (!saved) return
            try {
                const shortcuts = JSON.parse(saved)
                if (!Array.isArray(shortcuts)) return
                const cells = new Set()
                const ids = new Set()
                const valid = shortcuts.filter(app => {
                    if (!app || typeof app.appName !== "string" || typeof app.appId !== "string"
                        || !app.appId || typeof app.iconFile !== "string" || !Number.isInteger(app.cell)
                        || app.cell < 0 || app.cell >= 12 || cells.has(app.cell) || ids.has(app.appId))
                        return false
                    cells.add(app.cell)
                    ids.add(app.appId)
                    return true
                })
                if (valid.length !== shortcuts.length) {
                    console.warn("Posiciones: hay accesos inválidos en el archivo")
                    return
                }
                homeApps.clear()
                for (const app of valid) homeApps.append(app)
            } catch (error) {
                console.warn("Posiciones:", error)
            }
        }

        IpcHandler {
            target: "crimsonNoir"
            function toggle(): void { phoneWindow.togglePhone() }
            function close(): void {
                phoneWindow.reopenAfterClose = false
                phoneWindow.closePhone(null)
            }
        }

        component PhoneBackdrop: Rectangle {
            radius: 34
            gradient: Gradient {
                GradientStop { position: 0; color: "#350c1c" }
                GradientStop { position: 0.55; color: "#190c16" }
                GradientStop { position: 1; color: "#0d090f" }
            }
        }

        component PhoneWallpaper: Image {
            id: image
            required property url wallpaper
            required property Item roundedMask

            source: directory.status === FolderListModel.Ready && directory.count > 0
                    && directory.indexOf(wallpaper) >= 0 ? wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: status === Image.Ready
            layer.enabled: visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: image.roundedMask
            }

            FolderListModel {
                id: directory
                readonly property string selected: image.wallpaper.toString()
                folder: selected ? selected.slice(0, selected.lastIndexOf("/") + 1) : ""
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                caseSensitive: false
                showDirs: false
            }
        }

        FileView {
            id: wallpaperSettings
            path: Quickshell.dataDir + "/fondo.txt"
            blockLoading: true
            blockWrites: true
            printErrors: false
            onSaveFailed: phoneWindow.showNotice("No se pudo guardar el fondo")
        }

        FileView {
            id: lockWallpaperSettings
            path: Quickshell.dataDir + "/fondo-bloqueo.txt"
            blockLoading: true
            blockWrites: true
            printErrors: false
            onSaveFailed: phoneWindow.showNotice("No se pudo guardar el fondo de bloqueo")
        }

        HyprlandFocusGrab {
            id: focusGrab
            windows: [phoneWindow]
            onCleared: {
                if (phone.unlocked && !phoneWindow.closing) phoneWindow.closePhone(null)
            }
        }

        FileView {
            id: positions
            path: Quickshell.dataDir + "/accesos-inicio.json"
            blockLoading: true
            blockWrites: true
            printErrors: false
            onSaveFailed: phoneWindow.showNotice("No se pudieron guardar los accesos")
        }

        ListModel {
            id: homeApps
            ListElement { appName: "Firefox"; appId: "firefox"; iconFile: "file:///usr/share/icons/hicolor/scalable/apps/firefox.svg"; cell: 0 }
            ListElement { appName: "Dolphin"; appId: "org.kde.dolphin"; iconFile: "file:///usr/share/icons/hicolor/scalable/apps/org.kde.dolphin.svg"; cell: 1 }
            ListElement { appName: "Steam"; appId: "steam"; iconFile: "file:///usr/share/icons/hicolor/256x256/apps/steam.png"; cell: 2 }
            ListElement { appName: "Ghostty"; appId: "com.mitchellh.ghostty"; iconFile: "file:///usr/share/icons/Papirus/48x48/apps/com.mitchellh.ghostty.svg"; cell: 3 }
            ListElement { appName: "Ajustes"; appId: "systemsettings"; iconFile: "file:///usr/share/icons/breeze/apps/32/preferences-system.svg"; cell: 4 }
            ListElement { appName: "Galería"; appId: "org.kde.gwenview"; iconFile: "file:///usr/share/icons/hicolor/128x128/apps/gwenview.png"; cell: 5 }
            ListElement { appName: "Música"; appId: "org.kde.elisa"; iconFile: "file:///usr/share/icons/hicolor/128x128/apps/elisa.png"; cell: 6 }
            ListElement { appName: "Calculadora"; appId: "org.kde.kcalc"; iconFile: "file:///usr/share/icons/breeze/apps/48/accessories-calculator.svg"; cell: 7 }
        }

        Timer {
            interval: 1000
            running: phoneWindow.visible
            repeat: true
            onTriggered: phoneWindow.now = new Date()
        }

        Timer {
            id: noticeTimer
            interval: 2200
            onTriggered: noticeText.text = ""
        }

        Component.onCompleted: {
            phoneWindow.restorePositions()
            phoneWindow.wallpaperUrl = wallpaperSettings.text().trim()
            phoneWindow.lockWallpaperUrl = lockWallpaperSettings.text().trim()
            if (Quickshell.env("CRIMSON_NOIR_START_HIDDEN") !== "1")
                phoneWindow.openPhone()
        }

        ParallelAnimation {
            id: openAnimation
            NumberAnimation { target: phone; property: "travel"; to: 0; duration: 590; easing.type: Easing.OutCubic }
            NumberAnimation { target: phone; property: "rotation"; to: 0; duration: 620; easing.type: Easing.OutCubic }
            NumberAnimation { target: phone; property: "opacity"; to: 1; duration: 290 }
            onFinished: {
                phone.unlocked = true
                focusGrab.active = true
            }
        }

        ParallelAnimation {
            id: closeAnimation
            NumberAnimation { target: phone; property: "travel"; to: 1; duration: 340; easing.type: Easing.InCubic }
            NumberAnimation { target: phone; property: "rotation"; to: 24; duration: 340; easing.type: Easing.InCubic }
            NumberAnimation { target: phone; property: "opacity"; to: 0; duration: 340 }
            onFinished: phoneWindow.finishClose()
        }

        component AppIcon: Item {
            id: appIcon
            property string preferred: ""
            property string iconName: ""
            readonly property string desktopIcon: {
                if (iconName.startsWith("/"))
                    return "file://" + iconName.split("/").map(encodeURIComponent).join("/")
                return iconName ? Quickshell.iconPath(iconName, true) : ""
            }

            Image {
                id: preferredImage
                anchors.fill: parent
                source: !themedImage.visible ? appIcon.preferred : ""
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Image {
                id: themedImage
                anchors.fill: parent
                source: appIcon.desktopIcon
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "◇"
                color: "#f04b64"
                font.pixelSize: Math.round(appIcon.height * 0.54)
                font.bold: true
                visible: !preferredImage.visible && !themedImage.visible
            }
        }

        FocusScope {
            id: homeFocus
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: phoneWindow.handleEscape()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: phoneWindow.closePhone(null)
            }

            Rectangle {
                id: phone
                width: 300
                height: 600
                scale: phoneWindow.phoneScale
                x: (homeFocus.width - width) / 2
                y: homeFocus.height - (height + height * scale) / 2 - 12 + travel * (height + 32)
                radius: 38
                color: "#111111"
                border.width: 3
                border.color: "#650000"
                rotation: 180
                opacity: 0

                property real travel: 1
                property bool unlocked: false
                property bool lockDismissed: false
                readonly property bool showHome: lockDismissed || unlockAnimation.running
                onUnlockedChanged: {
                    if (unlocked && !phoneWindow.closing) unlockAnimation.start()
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Item {
                    id: screenContent
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    enabled: phone.unlocked && !phoneWindow.closing

                    PhoneBackdrop {
                        id: home
                        anchors.fill: parent

                        Rectangle {
                            id: wallpaperMask
                            anchors.fill: parent
                            radius: home.radius
                            visible: false
                            layer.enabled: true
                        }

                        PhoneWallpaper {
                            id: wallpaperImage
                            anchors.fill: parent
                            wallpaper: phoneWindow.wallpaperUrl
                            roundedMask: wallpaperMask
                            visible: status === Image.Ready && phone.showHome
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 13
                            visible: phone.showHome
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            width: 28
                            height: 28
                            radius: 14
                            color: "#b0101015"
                            border.color: "#805d202a"
                            Accessible.role: Accessible.Button
                            Accessible.name: "Cambiar fondo"
                            Accessible.onPressAction: phoneWindow.wallpaperOptionsOpen = true

                            Text {
                                anchors.centerIn: parent
                                text: "⚙︎"
                                color: "#fff1f4"
                                font.pixelSize: 17
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: phoneWindow.wallpaperOptionsOpen = true
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 42
                            visible: phone.showHome
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatTime(phoneWindow.now, "hh:mm")
                                color: "#fff1f4"
                                font.pixelSize: 55
                                font.weight: Font.Light
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: phoneWindow.fechaEspanol()
                                color: "#db9caa"
                                font.pixelSize: 13
                            }
                        }

                        Item {
                            id: freeHomeArea
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 161
                            width: 272
                            height: 276
                            visible: phone.showHome

                            readonly property int columns: 4
                            readonly property int rows: 3
                            readonly property real cellWidth: width / columns
                            readonly property real cellHeight: height / rows
                            property int dropCell: -1

                            function cellAt(point) {
                                if (point.x < 0 || point.x >= width || point.y < 0 || point.y >= height)
                                    return -1
                                return Math.floor(point.y / cellHeight) * columns
                                       + Math.floor(point.x / cellWidth)
                            }

                            Rectangle {
                                visible: freeHomeArea.dropCell >= 0
                                x: (freeHomeArea.dropCell % freeHomeArea.columns) * freeHomeArea.cellWidth + 3
                                y: Math.floor(freeHomeArea.dropCell / freeHomeArea.columns) * freeHomeArea.cellHeight + 3
                                width: freeHomeArea.cellWidth - 6
                                height: freeHomeArea.cellHeight - 6
                                radius: 12
                                color: "transparent"
                                border.color: "#f04b64"
                            }

                            Repeater {
                                model: homeApps
                                delegate: Item {
                                    id: appSlot
                                    required property int index
                                    required property int cell
                                    required property string appName
                                    required property string appId
                                    required property string iconFile
                                    width: freeHomeArea.cellWidth
                                    height: freeHomeArea.cellHeight
                                    x: (cell % freeHomeArea.columns) * width
                                    y: Math.floor(cell / freeHomeArea.columns) * height
                                    z: shortcutMouse.held ? 1 : 0

                                    Item {
                                        id: movableIcon
                                        width: appSlot.width
                                        height: appSlot.height
                                        scale: shortcutMouse.held ? 1.14 : 1
                                        opacity: shortcutMouse.held ? 0.84 : 1
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        Behavior on opacity { NumberAnimation { duration: 100 } }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 50; height: 50; radius: 14
                                            color: "#b8201720"; border.color: "#704f2632"
                                            AppIcon {
                                                anchors.centerIn: parent
                                                width: 34; height: 34
                                                preferred: appSlot.iconFile
                                                iconName: DesktopEntries.byId(appSlot.appId)?.icon ?? appSlot.appId
                                            }
                                        }

                                        Text {
                                            anchors.top: parent.top
                                            anchors.topMargin: 55
                                            width: parent.width
                                            text: appSlot.appName
                                            color: "white"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: shortcutMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        pressAndHoldInterval: 350
                                        property bool held: false
                                        property bool suppressLaunch: false
                                        property point pressPoint

                                        function clearDrag() {
                                            movableIcon.x = 0
                                            movableIcon.y = 0
                                            freeHomeArea.dropCell = -1
                                            held = false
                                        }

                                        onPressed: (mouse) => {
                                            if (mouse.button !== Qt.LeftButton) return
                                            pressPoint = Qt.point(mouse.x, mouse.y)
                                            suppressLaunch = false
                                        }
                                        onPressAndHold: (mouse) => {
                                            if (mouse.button !== Qt.LeftButton || suppressLaunch) return
                                            suppressLaunch = true
                                            held = true
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!(mouse.buttons & Qt.LeftButton)) return
                                            const dx = mouse.x - pressPoint.x
                                            const dy = mouse.y - pressPoint.y
                                            if (Math.hypot(dx, dy) >= 8) suppressLaunch = true
                                            if (!held) return
                                            movableIcon.x = dx
                                            movableIcon.y = dy
                                            freeHomeArea.dropCell = freeHomeArea.cellAt(
                                                shortcutMouse.mapToItem(freeHomeArea, mouse.x, mouse.y))
                                        }
                                        onReleased: (mouse) => {
                                            if (mouse.button !== Qt.LeftButton || !held) return
                                            const destination = freeHomeArea.cellAt(
                                                shortcutMouse.mapToItem(freeHomeArea, mouse.x, mouse.y))
                                            clearDrag()
                                            if (destination >= 0)
                                                phoneWindow.moveShortcut(appSlot.index, destination)
                                        }
                                        onCanceled: {
                                            suppressLaunch = true
                                            clearDrag()
                                        }
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                phoneWindow.contextHomeIndex = appSlot.index
                                                phoneWindow.contextApp = {name: appSlot.appName}
                                            } else if (!suppressLaunch) {
                                                phoneWindow.launchShortcut(appSlot.appId, appSlot.appName)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: dock
                            visible: phone.showHome
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 20
                            width: 258; height: 72; radius: 23
                            color: "#bc09090c"; border.color: "#805a1727"; border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 23
                                Repeater {
                                    model: ListModel {
                                        ListElement { appId: "firefox"; label: "Firefox"; iconFile: "file:///usr/share/icons/hicolor/scalable/apps/firefox.svg" }
                                        ListElement { appId: "org.kde.dolphin"; label: "Dolphin"; iconFile: "file:///usr/share/icons/hicolor/scalable/apps/org.kde.dolphin.svg" }
                                        ListElement { appId: "com.mitchellh.ghostty"; label: "Ghostty"; iconFile: "file:///usr/share/icons/Papirus/48x48/apps/com.mitchellh.ghostty.svg" }
                                        ListElement { appId: "systemsettings"; label: "Ajustes"; iconFile: "file:///usr/share/icons/breeze/apps/32/preferences-system.svg" }
                                    }
                                    delegate: Item {
                                        id: dockSlot
                                        required property string appId
                                        required property string label
                                        required property string iconFile
                                        width: 39; height: 39
                                        AppIcon {
                                            anchors.centerIn: parent
                                            width: 35; height: 35
                                            preferred: dockSlot.iconFile
                                            iconName: DesktopEntries.byId(dockSlot.appId)?.icon ?? dockSlot.appId
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: phoneWindow.launchShortcut(dockSlot.appId, dockSlot.label)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: dock.top
                            anchors.bottomMargin: 9
                            visible: phone.showHome
                            width: 100; height: 23; radius: 12
                            color: "#b0101015"; border.color: "#805d202a"
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "⌃"; color: "#f04b64"; font.pixelSize: 17 }
                                Text { text: "Apps"; color: "white"; font.pixelSize: 11 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: phoneWindow.openDrawer()
                            }
                        }
                    }

                    Item {
                        id: lockScreen
                        anchors.fill: parent
                        z: 20
                        visible: !phone.lockDismissed
                        property real progress: 0

                        PhoneBackdrop {
                            width: lockScreen.width
                            height: lockScreen.height
                            y: -height * lockScreen.progress

                            PhoneWallpaper {
                                id: lockWallpaperImage
                                anchors.fill: parent
                                wallpaper: phoneWindow.lockWallpaperUrl
                                roundedMask: wallpaperMask
                            }

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 96
                                spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatTime(phoneWindow.now, "hh:mm")
                                    color: "#fff1f4"
                                    font.pixelSize: 64
                                    font.weight: Font.Light
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: phoneWindow.fechaEspanol()
                                    color: "#db9caa"
                                    font.pixelSize: 13
                                }
                            }

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 30
                                spacing: 9
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 68
                                    height: 4
                                    radius: 2
                                    color: "#db9caa"
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                        }

                        NumberAnimation {
                            id: unlockAnimation
                            target: lockScreen
                            property: "progress"
                            to: 1
                            duration: 360
                            easing.type: Easing.InOutCubic
                            onFinished: phone.lockDismissed = true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 16
                        visible: phoneWindow.wallpaperOptionsOpen
                        color: "#99000000"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: phoneWindow.wallpaperOptionsOpen = false
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 245
                            height: 145
                            radius: 17
                            color: "#1a131b"
                            border.color: "#9b344c"

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 30
                                spacing: 10
                                Repeater {
                                    model: [
                                        { target: "home", label: "Fondo de inicio" },
                                        { target: "lock", label: "Fondo de bloqueo" }
                                    ]
                                    delegate: Rectangle {
                                        id: option
                                        required property var modelData
                                        width: parent.width
                                        height: 48
                                        radius: 10
                                        color: "#40202b"
                                        Accessible.role: Accessible.Button
                                        Accessible.name: modelData.label
                                        Accessible.onPressAction: choose()

                                        function choose() {
                                            phoneWindow.wallpaperOptionsOpen = false
                                            phoneWindow.wallpaperTarget = modelData.target
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: option.modelData.label
                                            color: "#fff1f4"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: option.choose()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        z: 17
                        active: phoneWindow.wallpaperTarget !== ""
                        sourceComponent: WallpaperPicker {
                            onChosen: file => phoneWindow.selectWallpaper(file)
                            onDismissed: phoneWindow.wallpaperTarget = ""
                        }
                    }

                    Rectangle {
                        id: drawer
                        width: parent.width
                        height: parent.height
                        radius: 34
                        color: "#fc09090d"
                        y: phoneWindow.drawerOpen ? 0 : 36
                        opacity: phoneWindow.drawerOpen ? 1 : 0
                        visible: phoneWindow.drawerOpen || opacity > 0
                        enabled: phoneWindow.drawerOpen
                        z: 10
                        Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 170 } }

                        MouseArea { anchors.fill: parent }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 17
                            anchors.topMargin: 35
                            spacing: 13

                            Item {
                                width: parent.width; height: 32
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "APLICACIONES"
                                    color: "#e44b65"
                                    font.bold: true
                                    font.pixelSize: 15
                                    font.letterSpacing: 1.2
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"; color: "white"; font.pixelSize: 20
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        onClicked: phoneWindow.closeDrawer()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width; height: 40; radius: 12
                                color: "#27202a"; border.color: "#744050"
                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    anchors.margins: 11
                                    color: "white"; font.pixelSize: 14; clip: true
                                    selectByMouse: true
                                    onTextChanged: drawerGrid.positionViewAtBeginning()
                                    onAccepted: {
                                        if (!phoneWindow.contextApp && phoneWindow.filteredApps.length)
                                            phoneWindow.closePhone(phoneWindow.filteredApps[0])
                                    }
                                    Text {
                                        anchors.fill: parent
                                        text: "Buscar aplicación..."
                                        color: "#a5a0a7"; font.pixelSize: 14
                                        visible: searchInput.text.length === 0
                                    }
                                }
                            }

                            GridView {
                                id: drawerGrid
                                width: parent.width
                                height: parent.height - 98
                                cellWidth: width / 4
                                cellHeight: 99
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: phoneWindow.filteredApps

                                delegate: Item {
                                    id: drawerSlot
                                    required property DesktopEntry modelData
                                    width: drawerGrid.cellWidth
                                    height: drawerGrid.cellHeight

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 5
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 50; height: 50; radius: 14
                                            color: "#b8201720"; border.color: "#704f2632"
                                            AppIcon {
                                                anchors.centerIn: parent
                                                width: 34; height: 34
                                                iconName: drawerSlot.modelData.icon
                                            }
                                        }
                                        Text {
                                            width: 57
                                            text: drawerSlot.modelData.name
                                            color: "white"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                phoneWindow.contextHomeIndex = -1
                                                phoneWindow.contextApp = drawerSlot.modelData
                                            } else {
                                                phoneWindow.closePhone(drawerSlot.modelData)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: drawerGrid.count === 0
                                    text: "No se encontraron aplicaciones"
                                    color: "#a5a0a7"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 18
                        visible: phoneWindow.contextApp !== null
                        color: "#99000000"
                        MouseArea { anchors.fill: parent; onClicked: phoneWindow.contextApp = null }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 245; height: 130; radius: 17
                            color: "#1a131b"; border.color: "#9b344c"; border.width: 1
                            MouseArea { anchors.fill: parent }
                            Column {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12
                                Text {
                                    text: phoneWindow.contextApp?.name ?? ""
                                    color: "white"; font.bold: true; font.pixelSize: 15
                                    elide: Text.ElideRight; width: parent.width
                                }
                                Rectangle {
                                    width: parent.width; height: 48; radius: 10; color: "#40202b"
                                    Text {
                                        anchors.centerIn: parent
                                        text: phoneWindow.contextHomeIndex < 0 ? "Agregar al inicio" : "Quitar del inicio"
                                        color: "white"; font.pixelSize: 14
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (phoneWindow.contextHomeIndex < 0) {
                                                phoneWindow.addShortcut(phoneWindow.contextApp)
                                            } else {
                                                homeApps.remove(phoneWindow.contextHomeIndex)
                                                phoneWindow.savePositions()
                                            }
                                            phoneWindow.contextApp = null
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: noticeText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 110
                        z: 19
                        color: "white"; font.pixelSize: 12
                        style: Text.Outline; styleColor: "black"
                    }
                }
            }
        }
    }
}
