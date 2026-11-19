pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id:panel
    required property var studio
    property string message:""
    property var request:["--status"]
    function run(arguments) {if(worker.running)return;request=arguments;worker.running=true}
    Process {
        id:worker
        command:["python3",Quickshell.shellPath("scripts/studio-shortcut.py")].concat(panel.request)
        stdout:StdioCollector {
            onStreamFinished:{
                try {
                    const result=JSON.parse(text)
                    panel.message=result.message
                    if(result.ok && result.shortcut){field.text=result.shortcut;panel.studio.shortcutLabel=result.shortcut}
                    if(result.ok && result.applied)panel.studio.centralShortcut=true
                }catch(e){panel.message="No se pudo verificar el atajo de Studio"}
            }
        }
    }
    Label {text:"Atajo único de Studio";color:"#eadce5";font.pixelSize:16}
    StudioField {id:field;Layout.fillWidth:true;text:panel.studio.shortcutLabel;placeholderText:"SUPER + P";enabled:!worker.running}
    Flow {Layout.fillWidth:true;spacing:6
        StudioButton {text:"Comprobar combinación";enabled:!worker.running;onClicked:panel.run(["--shortcut",field.text])}
        StudioButton {text:"Aplicar atajo al lanzador";enabled:!worker.running;onClicked:panel.run(["--shortcut",field.text,"--apply"])}
    }
    Label {Layout.fillWidth:true;text:panel.message;color:"#dfb4c5";wrapMode:Text.WordWrap}
    Label {Layout.fillWidth:true;text:"Aplicar comprueba conflictos en Hyprland, respalda su archivo y modifica únicamente el enlace existente de Studio. Después recarga la configuración de Hyprland y activa el lanzador. Los accesos IPC de cada editor se conservan.";color:"#bea8b3";wrapMode:Text.WordWrap;font.pixelSize:11}
    Component.onCompleted:run(["--status"])
}
