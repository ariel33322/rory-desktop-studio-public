import QtQuick
import QtQuick.Controls
Slider {
    id: slider
    width: parent.width
    from: 0; to: 1; stepSize: 0.01
    background: Rectangle {
        x: slider.leftPadding; y: (slider.height-height)/2
        width: slider.availableWidth; height: 5; radius: 3; color: "#493138"
        Rectangle { width: slider.visualPosition*parent.width; height: 5; radius: 3; color: "#e92a4c" }
    }
    handle: Rectangle {
        x: slider.leftPadding+slider.visualPosition*(slider.availableWidth-width)
        y: (slider.height-height)/2
        implicitWidth: 16; implicitHeight: 16; radius: 8
        color: slider.enabled ? "#ffd6dc" : "#746369"; border.color: "#dc2445"; border.width: 2
    }
}
