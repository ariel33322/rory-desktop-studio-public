pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

ShellRoot {
    id: test
    function check(condition, label) { if (!condition) throw new Error(label) }
    function find(root, name) {
        if (root.objectName === name) return root
        for (const child of root.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }

    SystemState { id: services }
    RoryNotificationSource { id: disabledSource; enabledReceiver: false }
    WallpaperSettings { id: wallpaper; studioVisibility: false }
    ClockSettings { id: clock; storagePath: Qt.resolvedUrl("clock.ini") }
    StudioController {
        id: studio
        storagePath: Qt.resolvedUrl("studio.ini")
        clockSettings: clock
        wallpaperSettings: wallpaper
        clockManager: null
        audioManager: null
    }
    CrimsonCoordinator { id: crimson; services: services }
    QtObject {
        id: first
        property string appName: "Prueba"
        property string appIcon: ""
        property string desktopEntry: "test"
        property string summary: "Primera"
        property string body: "Contenido de prueba"
        property var actions: []
        function dismiss() { fixture.notifications = fixture.notifications.filter(note => note !== first) }
    }
    QtObject {
        id: second
        property string appName: "Prueba"
        property string appIcon: ""
        property string desktopEntry: "test"
        property string summary: "Segunda"
        property string body: "Otro contenido"
        property var actions: []
    }
    QtObject {
        id: fixture
        property var notifications: [first,second]
        property string receiverStatus: "ready"
        function timeFor(note) { return null }
        function clear() { notifications = [] }
    }
    RoryBar {
        id: bar
        modelData: Quickshell.screens[0]
        services: services; wallpaperSettings: wallpaper
        theme: studio.roryBarTheme
        crimson: crimson; crimsonConfig: studio.effectiveRoryCrimson
        notificationOptions: studio.notificationOptions
        notificationSource: fixture
    }
    Window {
        visible: true
        width: 400; height: 450
        RoryNotificationCenter { id: center; width: parent.width; theme: "sakura"; source: fixture; options: studio.notificationOptions }
    }
    Timer {
        running: true; repeat: true; interval: 260
        property int step: -1
        onTriggered: {
            try {
                const battery = test.find(bar.contentItem,"roryBarBatteryIndicator")
                const bell = test.find(bar.contentItem,"roryBarNotificationIndicator")
                if (step === -1) {
                    bar.showBar(false)
                } else if (step === 0) {
                    studio.globalBarTheme = "sakura"
                    test.check(disabledSource.receiverStatus === "disabled" && disabledSource.notifications.length === 0, "Opt-in receptor starts disabled")
                    test.check(!!battery && !!bell && bell.visible, "Both indicators exist")
                    test.check(center.entries.length === 2 && center.entries[0].header === "Prueba", "Grouped, same app")
                    studio.notificationOptions.groupByApp = false
                    test.check(center.entries[0].header === "", "Ungrouped")
                    battery.clicked()
                    test.check(bar.activePage === "battery" && !crimson.visible, "Battery routes only to original panel")
                } else if (step === 1) {
                    bell.clicked()
                    test.check(bar.activePage === "notifications" && !crimson.visible, "Bell replaces battery")
                    first.dismiss()
                    test.check(center.entries.length === 1, "Individual dismissal")
                    fixture.clear()
                    test.check(center.entries.length === 0, "Clear and empty state")
                    bell.clicked()
                } else {
                    test.check(bar.panelProgress === 0, "Second click closes bell panel")
                    studio.notificationOptions.showIcon = false
                    test.check(!bell.visible, "Icon may be hidden")
                    console.log("RORY_NOTIFICATION_TEST_PASS")
                    Qt.exit(0)
                }
                step++
            } catch (error) { console.error("RORY_NOTIFICATION_TEST_FAIL", error); Qt.exit(1) }
        }
    }
}
