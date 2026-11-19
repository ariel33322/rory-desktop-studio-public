pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id:panel
    required property WallpaperSettings settings
    implicitHeight:content.implicitHeight
    Column {
        id:content;width:parent.width;spacing:10
        RowLayout {
            width: parent.width
            Text { text: "Encuadre"; color: "#d5c3cb"; font.pixelSize: 12 }
            ComboBox {
                id: fitPicker;objectName:"wallpaperFitMode"
                Layout.fillWidth: true
                model: ["Rellenar", "Ajustar", "Centrar"]
                currentIndex: ({fill: 0, fit: 1, center: 2})[panel.settings.fitMode] ?? 0
                onActivated: index => panel.settings.fitMode = ["fill", "fit", "center"][index]
                background: Rectangle { color: "#25171e"; radius: 5; border.color: "#713044" }
                contentItem: Text { leftPadding: 9; text: fitPicker.displayText; color: "#f4e8eb"; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 }
            }
        }
        RowLayout {
            width: parent.width
            Text { text: "Oscurecer"; color: "#d5c3cb"; font.pixelSize: 12 }
            Slider {objectName:"wallpaperDim"; Layout.fillWidth: true; from: 0; to: 0.55; value: panel.settings.dim; onMoved: panel.settings.dim = value }
            Text { text: Math.round(panel.settings.dim * 100) + "%"; color: "#b99da8"; font.pixelSize: 11 }
        }
    }
}
