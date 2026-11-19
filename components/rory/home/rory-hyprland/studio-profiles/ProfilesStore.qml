pragma Singleton
import QtQml
import QtCore
QtObject {
 property alias data:saved.data
 readonly property Settings storage:Settings {
  id:saved
  location:Qt.resolvedUrl("../.studio-profiles.ini")
  category:"RoryStudioProfiles"
  property string data:""
 }
}
