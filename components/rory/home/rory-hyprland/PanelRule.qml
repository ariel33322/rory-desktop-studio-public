import QtQuick
Item {
    width: parent.width
    height: 17
    Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: "#812237" }
    Image { source: "art/floral-corner.svg"; width: 30; height: 25; y: -4; opacity: 0.8 }
    Image { source: "art/floral-corner.svg"; width: 30; height: 25; x: parent.width-width; y: -4; mirror: true; opacity: 0.8 }
}
