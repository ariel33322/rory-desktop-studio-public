pragma Singleton
import QtQml
import QtCore

QtObject {
    property alias data: saved.data
    readonly property Settings storage: Settings {
        id: saved
        location: Qt.resolvedUrl("../.audio-particles.ini")
        category: "RoryAudioParticles"
        // Empty keeps old configurations and profiles particle-free.
        property string data: ""
    }
}
