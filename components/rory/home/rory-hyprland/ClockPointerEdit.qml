pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: editLayer
    required property var screen
    required property var settings
    required property Item face
    property bool editing: settings.pointerEditMode

    function applyPosition(startX, startY, deltaX, deltaY) {
        editLayer.settings.leftPercent = Math.max(0, Math.min(
            (editLayer.screen.width - editLayer.face.width) / editLayer.screen.width,
            (startX + deltaX) / editLayer.screen.width))
        editLayer.settings.topPercent = Math.max(0, Math.min(
            (editLayer.screen.height - editLayer.face.height) / editLayer.screen.height,
            (startY + deltaY) / editLayer.screen.height))
    }

    function applySize(startX, startY, startWidth, startHeight, deltaX, deltaY, proportional, timeSize) {
        const maxWidth = Math.max(40, Math.min(4096, screen.width - startX))
        const maxHeight = Math.max(40, Math.min(4096, screen.height - startY))
        let width = Math.max(40, Math.min(maxWidth, startWidth + deltaX))
        let height = Math.max(40, Math.min(maxHeight, startHeight + deltaY))
        if (proportional) {
            const minScale = Math.max(40 / startWidth, 40 / startHeight)
            const maxScale = Math.min(maxWidth / startWidth, maxHeight / startHeight)
            const scale = Math.min(maxScale, Math.max(minScale, width / startWidth))
            width = startWidth * scale
            height = startHeight * scale
            settings.timeSize = Math.max(8, Math.min(300, Math.round(timeSize * scale)))
        }
        settings.customWidth = Math.round(width)
        settings.customHeight = Math.round(height)
        applyPosition(startX, startY, 0, 0)
    }

    Rectangle {
        x: editLayer.face.x
        y: editLayer.face.y
        width: editLayer.face.width
        height: editLayer.face.height
        visible: editLayer.editing
        color: "transparent"
        border.width: 1
        border.color: editLayer.settings.accent
        opacity: 0.75
    }

    DragHandler {
        id: adjustClock
        enabled: editLayer.editing
        acceptedButtons: Qt.LeftButton
        target: null
        property real startX: 0
        property real startY: 0
        property real startWidth: 0
        property real startHeight: 0
        property real startTimeSize: 0
        property bool resizing: false
        property bool proportional: false

        onActiveChanged: {
            if (!active) return
            resizing = centroid.pressPosition.x >= editLayer.face.x + editLayer.face.width - 40
                && centroid.pressPosition.y >= editLayer.face.y + editLayer.face.height - 40
            startX = editLayer.face.x
            startY = editLayer.face.y
            proportional = !!(centroid.modifiers & Qt.ShiftModifier)
            if (resizing) {
                startWidth = editLayer.face.width
                startHeight = editLayer.face.height
                startTimeSize = editLayer.settings.timeSize
            }
        }

        onActiveTranslationChanged: {
            if (!active) return
            if (resizing) {
                editLayer.applySize(startX, startY, startWidth, startHeight,
                    activeTranslation.x, activeTranslation.y, proportional, startTimeSize)
                return
            }

            editLayer.applyPosition(startX, startY, activeTranslation.x, activeTranslation.y)
        }
    }

    Rectangle {
        id: resizeGrip
        visible: editLayer.editing
        x: editLayer.face.x + editLayer.face.width - width
        y: editLayer.face.y + editLayer.face.height - height
        width: 28
        height: 28
        radius: 5
        color: "#a810090f"
        border.width: 1
        border.color: editLayer.settings.accent
        Text {
            anchors.centerIn: parent
            text: "↘"
            color: editLayer.settings.accent
            font.pixelSize: 20
        }
    }
}
