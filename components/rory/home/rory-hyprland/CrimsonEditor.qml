pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "TaskbarModel.js" as Model
import "RoryTheme.js" as Theme

StudioSection {
    id: editor
    title:"Centro de control"
    expanded:false
    property bool forRoryBar: false
    property string appearanceTheme:config.theme ?? "crimson"
    readonly property var paint:Theme.center(Object.assign({},config,{theme:appearanceTheme}))
    function editDimension(key,value) {
        if(appearanceTheme==="sakura" && ["width","spacing"].includes(key))
            edit("sakuraLayout",Object.assign({},config.sakuraLayout,{[key]:value}))
        else edit(key,value)
    }
    function editColor(key,value) {
        if(appearanceTheme==="sakura")edit("sakuraColors",Object.assign({},config.sakuraColors,{[key]:value}))
        else edit(key,value)
    }
    required property var config
    required property var controller
    required property string owner
    signal changed(var next)
    readonly property var labels: ({wifi:"Wi-Fi",bluetooth:"Bluetooth",media:"Multimedia",
        brightness:"Brillo",volume:"Volumen",kde:"KDE Connect",airplane:"Modo avión",dnd:"No molestar",
        power:"Ahorro",record:"Grabación",night:"Noche",capture:"Captura",settings:"Configuración",flash:"Linterna"})
    function cardRow(id) {
        return ["wifi","bluetooth"].includes(id) ? 0 : id==="kde" ? 2 : 1
    }
    function canMoveCard(index,step) {
        const adjacent=config.cards[index+step]
        return !!adjacent && cardRow(adjacent.id)===cardRow(config.cards[index].id)
    }
    function edit(key,value) { changed(Object.assign({},config,{[key]:value})) }
    function entry(key,index,offset) {
        const next=Model.copy(config[key])
        if(offset===0) next[index].enabled=!next[index].enabled
        else {
            const move=next.splice(index,1)[0]
            next.splice(index+offset,0,move)
        }
        edit(key,next)
    }
    StudioThemePicker {visible:!editor.forRoryBar;title:"Tema de este centro";theme:editor.config.theme;onChosen:value=>editor.edit("theme",value)}
    StudioToggle {text:editor.forRoryBar ? "Activación desde los indicadores de RoryBar" : "Botón del centro en esta barra";checked:editor.config.enabled;onToggled:editor.edit("enabled",checked)}
    StudioToggle {visible:!editor.forRoryBar;text:"Abrir al pasar el cursor sobre el botón";checked:editor.config.openOnHover;onToggled:editor.edit("openOnHover",checked)}
    StudioToggle {text:"Cerrar al abrir una aplicación o el selector de captura";checked:editor.config.closeAfterAction;onToggled:editor.edit("closeAfterAction",checked)}
    StudioToggle {text:"Adornos florales originales";checked:editor.config.decorative;onToggled:editor.edit("decorative",checked)}
    Label {text:"Imagen decorativa local (ruta absoluta, opcional)";color:"#dfd0d9";Layout.fillWidth:true;wrapMode:Text.WordWrap}
    StudioField {
        Layout.fillWidth:true
        text:editor.config.decoration
        property string inputOwner:""
        onTextEdited:inputOwner=editor.owner
        onEditingFinished:if(inputOwner===editor.owner && text!==editor.config.decoration)editor.edit("decoration",text.trim())
    }
    Repeater {
        model:[["width","Ancho"],["height","Altura máxima"],["x","Ajuste horizontal"],["y","Separación vertical"],
            ["opacity","Opacidad"],["borderWidth","Grosor del borde"],["radius","Radio de esquinas"],
            ["spacing","Separación interna"],["iconSize","Tamaño de iconos"],["duration","Animación (ms)"]]
        delegate:VisualizerSlider {
            required property var modelData
            Layout.fillWidth:true
            controller:editor.controller
            label:modelData[1];explanation:""
            from:Model.centerNumbers[modelData[0]][0];to:editor.appearanceTheme==="sakura" && modelData[0]==="width" ? 500 : Model.centerNumbers[modelData[0]][1]
            decimals:modelData[0]==="opacity" ? 2 : 0
            value:editor.paint[modelData[0]]
            onValueEdited:v=>editor.editDimension(modelData[0],v)
        }
    }
    Repeater {
        model:[["background","Fondo"],["border","Borde"],["accent","Acento"]]
        delegate:ColumnLayout {
            id: colorGroup
            required property var modelData
            Layout.fillWidth:true
            Label {text:colorGroup.modelData[1];color:"#dfd0d9"}
            StudioColorEditor {
                Layout.fillWidth:true
                controller:editor.controller
                contextKey:editor.owner+"/center/"+editor.appearanceTheme+"/"+colorGroup.modelData[0]
                value:editor.paint[colorGroup.modelData[0]]
                onColorEdited:c=>editor.editColor(colorGroup.modelData[0],c)
            }
        }
    }
    Label {text:"Tarjetas";color:"#dfd0d9"}
    Repeater {
        model:editor.config.cards
        delegate:RowLayout {
            id:cardRow
            required property var modelData
            required property int index
            Layout.fillWidth:true
            StudioToggle {Layout.fillWidth:true;text:editor.labels[cardRow.modelData.id];checked:cardRow.modelData.enabled;onToggled:editor.entry("cards",cardRow.index,0)}
            StudioToolButton {text:"↑";enabled:editor.canMoveCard(cardRow.index,-1);onClicked:editor.entry("cards",cardRow.index,-1)}
            StudioToolButton {text:"↓";enabled:editor.canMoveCard(cardRow.index,1);onClicked:editor.entry("cards",cardRow.index,1)}
        }
    }
    Label {text:"Acciones rápidas";color:"#dfd0d9"}
    Repeater {
        model:editor.config.quick
        delegate:RowLayout {
            id:row
            required property var modelData
            required property int index
            Layout.fillWidth:true
            StudioToggle {Layout.fillWidth:true;text:editor.labels[row.modelData.id];checked:row.modelData.enabled;onToggled:editor.entry("quick",row.index,0)}
            StudioToolButton {text:"↑";enabled:row.index>0;onClicked:editor.entry("quick",row.index,-1)}
            StudioToolButton {text:"↓";enabled:row.index+1<editor.config.quick.length;onClicked:editor.entry("quick",row.index,1)}
        }
    }
}
