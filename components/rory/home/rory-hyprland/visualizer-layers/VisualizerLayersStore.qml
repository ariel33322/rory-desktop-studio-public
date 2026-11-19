pragma Singleton
import QtQml
import QtCore
QtObject {
 property alias document: saved.document
 readonly property LegacySettingsReader legacyReader: LegacySettingsReader {}
 readonly property string migrationError: legacyReader.error || ""
 readonly property var legacySnapshot: legacyReader.values || ({})
 property alias profiles: saved.profiles
 readonly property Settings storage: Settings {
  id: saved
  location: Qt.resolvedUrl("../.visualizer-layers.ini")
  category: "RoryVisualizerV2"
  property string document: ""
  property string profiles: "{}"
 }
}
