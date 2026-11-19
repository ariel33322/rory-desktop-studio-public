pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: background
    required property var settings
    visible: settings.backgroundEnabled
    scale: settings.backgroundScale
    rotation: settings.backgroundRotation
    opacity: settings.backgroundOpacity * settings.widgetOpacity
    // This item is a sibling of the text face: no layout or text geometry changes.
    Rectangle {
        anchors.fill:parent
        radius:background.settings.backgroundRadius
        color:background.settings.backgroundColor
    }
    Image {
        id: picture
        anchors.fill:parent
        source:background.settings.backgroundImageUrl
        fillMode:background.settings.backgroundFit === "contain" ? Image.PreserveAspectFit
            : background.settings.backgroundFit === "stretch" ? Image.Stretch
            : background.settings.backgroundFit === "original" ? Image.Pad : Image.PreserveAspectCrop
        asynchronous:true
        visible:false
        layer.enabled:true
    }
    Rectangle {
        id:roundedMask
        anchors.fill:parent
        radius:background.settings.backgroundRadius
        color:"white"
        visible:false
        layer.enabled:true
    }
    MultiEffect {
        anchors.fill:parent
        source:picture
        visible:picture.status === Image.Ready && background.settings.backgroundImage !== ""
        maskEnabled:true
        maskSource:roundedMask
        maskThresholdMin:0.5
        maskSpreadAtMin:0
    }
    readonly property bool imageError: picture.status === Image.Error
}
