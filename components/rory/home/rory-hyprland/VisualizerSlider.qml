pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property string label
    required property string explanation
    required property real from
    required property real to
    required property real value
    required property var controller
    property string suffix: ""
    property int decimals: 0
    property real step: decimals > 0 ? 1 / Math.pow(10, decimals) : 1
    signal valueEdited(real value)
    signal interactionStarted()
    signal interactionFinished()

    function formatted(number) {
        return control.decimals > 0
            ? Number(number).toFixed(control.decimals)
            : String(Math.round(number))
    }

    spacing:5
    Label {Layout.fillWidth:true;text:control.label;color:"#e6dde2";font.pixelSize:13;wrapMode:Text.WordWrap}
    Connections {
        target:control.controller
        ignoreUnknownSignals:true
        function onDocumentChanged(){numericValue.cancelEdit()}
        function onLayerDocumentChanged(){numericValue.cancelEdit()}
        function onRestoringChanged(){if(control.controller.restoring)numericValue.cancelEdit()}
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Slider {
            id: valueSlider
            objectName:"valueSlider"
            Layout.fillWidth: true
            Layout.minimumWidth: 32
            from: control.from
            to: control.to
            stepSize: control.step
            snapMode: control.step > 0 ? Slider.SnapAlways : Slider.NoSnap
            value: control.value
            background:Rectangle {x:valueSlider.leftPadding;y:valueSlider.topPadding+(valueSlider.availableHeight-height)/2;implicitWidth:120;implicitHeight:4;width:valueSlider.availableWidth;height:4;radius:2;color:"#45383f"
                Rectangle {width:valueSlider.visualPosition*parent.width;height:parent.height;radius:2;color:"#995269"}}
            handle:Rectangle {x:valueSlider.leftPadding+valueSlider.visualPosition*(valueSlider.availableWidth-width);y:valueSlider.topPadding+(valueSlider.availableHeight-height)/2;implicitWidth:14;implicitHeight:14;radius:7;color:valueSlider.pressed ? "#e5b6c4" : "#c68a9d";border.color:"#452a35"}
            onMoved: control.valueEdited(value)
            onPressedChanged: {
                if (pressed) {
                    control.controller.beginTransaction()
                    control.interactionStarted()
                } else {
                    control.controller.endTransaction()
                    control.interactionFinished()
                }
            }
        }
        StudioField {
            id: numericValue
            objectName:"numericValue"
            Layout.preferredWidth: 86
            Layout.minimumWidth: 72
            Layout.maximumWidth: 110
            text: control.formatted(control.value)
            property bool registeredInput:false
            function pendingChanged(){if(registeredInput===dirty)return;registeredInput=dirty;if(control.controller && typeof control.controller.setInputPending==="function")control.controller.setInputPending(numericValue,dirty)}
            function finishForProfile(){if(dirty)editingFinished()}
            function cancelEdit(){dirty=false;pendingChanged();editBaseValue=control.value;text=control.formatted(control.value)}
            property bool dirty: false
            property real editBaseValue: control.value
            Component.onDestruction:{dirty=false;pendingChanged()}
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            onActiveFocusChanged: if(activeFocus){editBaseValue=control.value;dirty=false;pendingChanged()}
            onTextEdited:{dirty=true;pendingChanged()}
            validator: DoubleValidator {
                bottom: control.from; top: control.to
                decimals: Math.max(0, control.decimals)
                notation: DoubleValidator.StandardNotation
            }
            onEditingFinished: {
                const parsed=Number(text.trim().replace(",", "."))
                const apply=dirty && acceptableInput && control.enabled && control.visible
                    && Number.isFinite(parsed) && parsed>=control.from && parsed<=control.to
                    && Math.abs(editBaseValue-control.value)<0.0000001
                    && Math.abs(parsed-control.value)>0.0000001
                dirty=false;pendingChanged()
                if(apply){control.controller.beginTransaction();control.valueEdited(parsed);control.controller.endTransaction()}
                editBaseValue=control.value
                text=control.formatted(control.value)
            }
            Connections {
                target: control
                function onValueChanged() {
                    // Loading a profile or changing selection cancels stale partial input.
                    numericValue.dirty=false;numericValue.pendingChanged()
                    numericValue.editBaseValue=control.value
                    numericValue.text=control.formatted(control.value)
                }
            }
        }
        Label {
            visible: control.suffix.length > 0
            text: control.suffix
            color: "#b99da8"
            font.pixelSize: 11
        }
    }
    Label {
        Layout.fillWidth: true
        visible:control.explanation.length>0
        text: control.explanation
        color: "#aa969d"; font.pixelSize: 11; wrapMode: Text.WordWrap
    }
}
