pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

StudioSection {
    id: editor
    required property var studio
    readonly property var options: studio.notificationOptions
    title: "Notificaciones de RoryBar"
    expanded: false

    Repeater {
        model: [["showIcon","Mostrar campana"],["receive","Recibir con Rory si no hay otro proveedor"],
                ["quiet","No molestar (silenciar aviso visual)"],["groupByApp","Agrupar por aplicación"],
                ["showMedia","Mostrar tarjeta multimedia"],["animate","Animar apertura y cierre"]]
        delegate: StudioToggle {
            required property var modelData
            text: modelData[1]
            checked: editor.options[modelData[0]]
            onToggled: editor.options[modelData[0]] = checked
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "El receptor de Rory usa memoria de sesión. Si ya hay un proveedor, ese proveedor sigue recibiendo los avisos."
        color: "#dbc1cf"
    }
    Repeater {
        model: [["panelWidth","Ancho (px)",280,540],["maxHeight","Altura máxima (px)",220,1000],
                ["offset","Desplazamiento horizontal (px)",-150,150],["opacity","Opacidad",.55,1],
                ["openMs","Apertura (ms)",0,500],["closeMs","Cierre (ms)",0,500]]
        delegate: VisualizerSlider {
            required property var modelData
            Layout.fillWidth: true
            controller: editor.studio.roryCrimsonInputs
            label: modelData[1]; explanation: ""
            from: modelData[2]; to: modelData[3]
            decimals: modelData[0] === "opacity" ? 2 : 0
            value: editor.options[modelData[0]]
            onValueEdited: value => editor.options[modelData[0]] = value
        }
    }
}
