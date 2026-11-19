pragma Singleton
import QtQml
import QtCore

QtObject {
    property alias data: saved.data
    readonly property Settings storage: Settings {
        id: saved
        location: Qt.resolvedUrl("../.audio-layers.ini")
        category: "RoryAudioLayers"
        // Empty is the legacy single-layer configuration. Never migrate profiles on disk.
        property string data: ""
    }
}
