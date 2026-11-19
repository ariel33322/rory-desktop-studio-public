pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
Column {
 id: card
 signal dismissed()
 spacing: 8
    property string confirmation: ""
    property string powerError: ""
    property var capabilities: ({})
    readonly property var powerActions: [
        { key: "Suspend", command: "suspend", label: "Suspender" },
        { key: "Reboot", command: "reboot", label: "Reiniciar" },
        { key: "PowerOff", command: "poweroff", label: "Apagar" }
    ]


Component.onCompleted: powerProbe.running = true
 component Detail: PanelText {}
    Process {
        id: powerProbe
        command: ["sh", "-c",
            'for action in Suspend Reboot PowerOff; do result=$(busctl --system --timeout=2s call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "Can$action" 2>/dev/null); printf "%s %s\n" "$action" "$result"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {}
                for (const line of text.trim().split("\n")) {
                    const match = /^(Suspend|Reboot|PowerOff) s "(yes|challenge)"$/.exec(line)
                    if (match) result[match[1]] = true
                }
                card.capabilities = result
            }
        }
    }

    Process {
        id: powerRequest
        stderr: StdioCollector { id: powerStderr }
        onExited: (code) => {
            if (code !== 0) card.powerError = powerStderr.text.trim() || "El sistema rechazó la acción."
            else card.dismissed()
        }
    }


Loader { width: parent.width; sourceComponent: powerPage }
    Component {
        id: powerPage
        Column {
            spacing: 8

            Repeater {
                model: card.powerActions
                RoryButton {
                    required property var modelData
                    width: parent.width
                    visible: card.capabilities[modelData.key] === true
                    enabled: !powerRequest.running
                    text: card.confirmation === modelData.key ? "Confirmar " + modelData.label.toLowerCase()
                        : modelData.label
                    selected: card.confirmation === modelData.key
                    onClicked: {
                        card.powerError = ""
                        if (card.confirmation !== modelData.key) {
                            card.confirmation = modelData.key
                            return
                        }
                        card.confirmation = ""
                        powerRequest.command = ["systemctl", modelData.command]
                        powerRequest.running = true
                    }
                }
            }

            Detail {
                visible: powerProbe.running || Object.keys(card.capabilities).length === 0
                text: powerProbe.running ? "Consultando al sistema…"
                    : "No hay acciones de energía disponibles en esta sesión."
            }

            Detail { visible: !!card.powerError; text: card.powerError }
        }
    }
}
