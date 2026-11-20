pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SakuraDecoration.js" as Sakura

StudioSection {
    id:editor
    required property var studio
    readonly property var config:studio.sakuraDecoration
    title:"Decoración Sakura de RoryBar"
    expanded:false
    StudioToggle {text:"Ramas de cerezo (desactiva para usar los adornos originales)";checked:editor.config.enabled;onToggled:editor.studio.editSakuraDecoration("enabled",checked)}
    StudioToggle {text:"Animar las ramas y los pétalos";checked:editor.config.animation;onToggled:editor.studio.editSakuraDecoration("animation",checked)}
    StudioButton {
        text:"Vista previa en RoryBar"
        enabled:editor.config.enabled && editor.studio.roryBarTheme==="sakura" && !!editor.studio.targetScreen
        onClicked:editor.studio.previewSakuraDecoration()
    }
    Label {
        Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#dbc1cf"
        visible:editor.studio.sakuraDecorationError!=="" || editor.studio.roryBarTheme!=="sakura"
        text:editor.studio.sakuraDecorationError || "Selecciona Sakura Pink para RoryBar para ver las ramas."
    }
    Repeater {
        model:[["count","Cantidad de pétalos"],["fall","Duración de caída (ms)"],["wind","Intensidad del viento"],
            ["shake","Intensidad de la sacudida"],["size","Tamaño de las ramas"],["opacity","Opacidad"],
            ["leftX","Rama izquierda · horizontal (px)"],["leftY","Rama izquierda · vertical (px)"],
            ["rightX","Rama derecha · horizontal (px)"],["rightY","Rama derecha · vertical (px)"]]
        delegate:VisualizerSlider {
            required property var modelData
            Layout.fillWidth:true
            controller:editor.studio.roryCrimsonInputs
            label:modelData[1];explanation:""
            from:Sakura.limits[modelData[0]][0];to:Sakura.limits[modelData[0]][1]
            decimals:["wind","shake","size","opacity"].includes(modelData[0]) ? 2 : 0
            value:editor.config[modelData[0]]
            onValueEdited:v=>editor.studio.editSakuraDecoration(modelData[0],v)
        }
    }
}
