pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id:notice
    required property var manager
    visible:!!manager.pending || manager.error!==""
    Label {Layout.fillWidth:true;color:"#efb0c0";text:notice.manager.error;visible:text!=="";wrapMode:Text.WordWrap}
    Label {
        Layout.fillWidth:true
        visible:!!notice.manager.pending
        text:{
            const request=notice.manager.pending
            if (!request) return ""
            const editors=request.clockConflict && request.audioConflict ? "el reloj y el visualizador"
                : request.clockConflict ? "el reloj" : "el visualizador"
            return "Este fondo reemplazaría cambios sin guardar en " + editors + "."
        }
        color:"#dfc8d3";wrapMode:Text.WordWrap
    }
    Label {Layout.fillWidth:true;visible:!!notice.manager.pending && notice.manager.pending.externalChange;text:"El fondo ya cambió. Cancelar conserva sus ajustes actuales y mantiene ocultos los widgets pendientes de aplicar.";color:"#bea8b3";font.pixelSize:11;wrapMode:Text.WordWrap}
    Flow {Layout.fillWidth:true;spacing:6;visible:!!notice.manager.pending
        StudioButton {text:"Guardar copias y aplicar";onClicked:notice.manager.resolve("copy")}
        StudioButton {text:"Descartar y aplicar";onClicked:notice.manager.resolve("discard")}
        StudioButton {text:"Cancelar";onClicked:notice.manager.resolve("cancel")}
    }
}
