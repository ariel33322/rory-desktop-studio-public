pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "RoryTheme.js" as Theme

ColumnLayout {
    id: center
    required property var source
    required property var options
    required property string theme
    signal dismissed()
    readonly property color ink: Theme.tone(theme, "#ffe9ee", "#F7C7DA")
    readonly property color accent: Theme.tone(theme, "#e45876", "#FF5B9A")
    readonly property var entries: {
        const notes = [...(source?.notifications ?? [])].reverse()
        if (!options?.groupByApp) return notes.map(note => ({note, header: ""}))
        const groups = new Map()
        for (const note of notes) {
            const key = note.desktopEntry || note.appName || ""
            if (!groups.has(key)) groups.set(key, [])
            groups.get(key).push(note)
        }
        const entries = []
        for (const group of groups.values()) {
            group.forEach((note, index) => entries.push({
                note, header: index === 0 && group.length > 1 ? (note.appName || "Aplicación") : ""
            }))
        }
        return entries
    }
    function iconFor(note) {
        if (note.appIcon.startsWith("file:///")) return note.appIcon
        if (note.appIcon.startsWith("/"))
            return "file://" + note.appIcon.split("/").map(encodeURIComponent).join("/")
        return Quickshell.iconPath(note.appIcon || note.desktopEntry, true)
            || Quickshell.iconPath("dialog-information", true)
    }

    spacing: 8
    SystemClock { id: clock; precision: SystemClock.Minutes }

    component PanelLabel: Label {
        color: center.ink
        textFormat: Text.PlainText
    }
    component PanelAction: RoryButton {
        theme: center.theme
        tooltipEnabled: false
    }

    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PanelLabel { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 36; font.family: "Liberation Serif" }
            PanelLabel { Layout.fillWidth: true; text: clock.date.toLocaleDateString(Qt.locale("es_MX"), "dddd d 'de' MMMM"); wrapMode: Text.Wrap }
        }
        PanelAction { text: "Cerrar"; onClicked: center.dismissed() }
    }
    Loader {
        Layout.fillWidth: true
        active: center.options?.showMedia ?? true
        visible: active
        sourceComponent: RoryNotificationMedia { theme: center.theme }
    }
    RowLayout {
        Layout.fillWidth: true
        PanelLabel {
            Layout.fillWidth: true
            text: "Notificaciones" + (center.entries.length ? " (" + center.entries.length + ")" : "")
            font.bold: true
            wrapMode: Text.Wrap
        }
        PanelAction {
            visible: center.source?.receiverStatus === "ready"
            text: center.options?.quiet ? "En silencio" : "No molestar"
            selected: center.options?.quiet ?? false
            onClicked: center.options.quiet = !center.options.quiet
        }
    }
    PanelLabel {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        visible: center.entries.length === 0
        text: ({
            ready: "No hay notificaciones.",
            external: "Otro servicio recibe las notificaciones de esta sesión.",
            checking: "Comprobando el bus de sesión…",
            starting: "Iniciando el receptor de Rory…",
            unavailable: "El bus de sesión no está disponible.",
            disabled: "Activa el receptor de Rory desde Super+P si tu sesión no tiene otro proveedor."
        })[center.source?.receiverStatus ?? "disabled"] || ""
    }
    PanelAction {
        visible: center.source?.receiverStatus === "external" || center.source?.receiverStatus === "unavailable"
        text: "Volver a comprobar"
        onClicked: center.source.check()
    }

    Repeater {
        model: center.entries
        delegate: ColumnLayout {
            id: entry
            required property var modelData
            readonly property var note: modelData.note
            property bool expanded: false
            Layout.fillWidth: true
            spacing: 3
            PanelLabel {
                visible: !!text
                text: entry.modelData.header
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: noteBody.implicitHeight + 16
                radius: 11
                color: Theme.tone(center.theme, "#24151d", "#25101E")
                border.color: Theme.tone(center.theme, "#713447", "#63324B")
                ColumnLayout {
                    id: noteBody
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Image {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: center.iconFor(entry.note)
                            asynchronous: true
                        }
                        PanelLabel {
                            Layout.fillWidth: true
                            text: entry.note.appName || entry.note.desktopEntry || "Aplicación"
                            elide: Text.ElideRight
                            opacity: .78
                        }
                        PanelLabel {
                            readonly property var arrival: center.source.timeFor(entry.note)
                            text: arrival ? Qt.formatTime(arrival, "HH:mm") : ""
                            opacity: .78
                        }
                        PanelAction { text: "Descartar"; onClicked: entry.note.dismiss() }
                    }
                    PanelLabel {
                        id: summary
                        Layout.fillWidth: true
                        text: entry.note.summary
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: entry.expanded ? 2147483647 : 2
                        elide: Text.ElideRight
                    }
                    PanelLabel {
                        id: message
                        Layout.fillWidth: true
                        visible: !!text
                        text: entry.note.body
                        wrapMode: Text.Wrap
                        maximumLineCount: entry.expanded ? 2147483647 : 2
                        elide: Text.ElideRight
                    }
                    PanelAction {
                        visible: entry.expanded || message.truncated || summary.truncated
                        text: entry.expanded ? "Contraer" : "Expandir"
                        onClicked: entry.expanded = !entry.expanded
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: !!entry.note.actions.length
                        spacing: 4
                        Repeater {
                            model: entry.note.actions
                            delegate: PanelAction {
                                required property var modelData
                                text: modelData.text || "Abrir"
                                width: Math.min(implicitWidth, parent.width)
                                onClicked: modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
    PanelAction {
        Layout.alignment: Qt.AlignRight
        visible: !!center.entries.length
        text: "Limpiar notificaciones"
        onClicked: center.source.clear()
    }
}
