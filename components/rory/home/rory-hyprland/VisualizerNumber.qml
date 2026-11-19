pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property string label
    required property real value
    required property real minimum
    required property real maximum
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    property string explanation: ""
    signal valueEdited(real value)

    function formatted(number) {
        return decimals > 0 ? Number(number).toFixed(decimals) : String(Math.round(number))
    }

    Label {
        Layout.fillWidth: true
        text: control.label
        color: "#eee4e7"
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    RowLayout {
        Layout.fillWidth: true
        TextField {
            id: numberField
            Layout.fillWidth: true
            implicitWidth: 88
            text: control.formatted(control.value)
            selectByMouse: true
            validator: DoubleValidator {
                bottom: control.minimum
                top: control.maximum
                decimals: Math.max(0, control.decimals)
                notation: DoubleValidator.StandardNotation
            }
            onEditingFinished: {
                if (acceptableInput)
                    control.valueEdited(Math.max(control.minimum,
                        Math.min(control.maximum, Number(text))))
                text = control.formatted(control.value)
            }
            Connections {
                target: control
                function onValueChanged() {
                    if (!numberField.activeFocus)
                        numberField.text = control.formatted(control.value)
                }
            }
        }
        Label { text: control.suffix; color: "#b99da8"; font.pixelSize: 11 }
    }
    Label {
        visible: control.explanation.length > 0
        Layout.fillWidth: true
        text: control.explanation
        color: "#aa969d"
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }
}
