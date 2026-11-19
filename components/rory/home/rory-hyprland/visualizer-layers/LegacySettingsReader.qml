import QtQml
import Quickshell.Io
import "../AudioLayers.js" as Layers
QtObject {
 readonly property FileView source: FileView {
  path:Qt.resolvedUrl("../.wallpaper-settings.ini").toString().replace("file://", "")
  blockLoading:true
 }
 // Read-only migration input. No setter, writer, or Settings instance targets the old INI.
 readonly property var snapshot: readSnapshot()
 readonly property var values: snapshot.values
 readonly property string error: snapshot.error
 function readSnapshot(){
  try {return {values:Layers.readLegacyIni(source.text()),error:""}}
  catch(failure){return {values:{},error:"No se pudo leer la configuración anterior: "+String(failure)}}
 }
}
