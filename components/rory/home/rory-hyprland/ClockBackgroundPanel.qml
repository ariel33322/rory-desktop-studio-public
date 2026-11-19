pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "WallpaperIdentity.js" as Wallpaper

ColumnLayout {
    id:panel
    required property ClockSettings settings
    required property var manager
    property string imageError:""
    function choose(url) {
        try {
            const normalized=Wallpaper.normalize(url)
            if (!/\.(png|jpe?g|webp)$/i.test(normalized)) throw new Error("Elige PNG, JPG o WebP")
            settings.backgroundImage=normalized
            settings.backgroundEnabled=true
            imageError=""
        } catch(e) {imageError=String(e.message || e)}
    }
    FileDialog {
        id:picker
        title:"Imagen de fondo del reloj"
        nameFilters:["Imágenes (*.png *.jpg *.jpeg *.webp)"]
        onAccepted:panel.choose(selectedFile)
    }
    StudioToggle {text:"Mostrar fondo";checked:panel.settings.backgroundEnabled;onToggled:panel.settings.backgroundEnabled=checked}
    Flow {Layout.fillWidth:true;spacing:6
        StudioButton {text:"Elegir imagen…";onClicked:picker.open()}
        StudioButton {text:"Quitar imagen · usar color";enabled:panel.settings.backgroundImage!=="";onClicked:{panel.settings.backgroundImage="";panel.imageError=""}}
    }
    Label {Layout.fillWidth:true;text:panel.settings.backgroundImage || "Color sólido";textFormat:Text.PlainText;color:"#bea8b3";wrapMode:Text.WrapAnywhere}
    Image {id:probe;source:panel.settings.backgroundImageUrl;visible:false;asynchronous:true}
    Label {Layout.fillWidth:true;visible:text!=="";text:panel.imageError || (probe.status===Image.Error ? "No se pudo cargar la imagen. Se muestra el color sólido; el perfil conserva la ruta." : "");color:"#efb0c0";wrapMode:Text.WordWrap}
    StudioColorEditor {Layout.fillWidth:true;controller:panel.manager.controller;value:panel.settings.backgroundColor;contextKey:panel.manager.activeId+"/background";onColorEdited:c=>panel.settings.backgroundColor=c}
    StudioCombo {Layout.fillWidth:true;model:["Contener","Cubrir","Estirar","Tamaño original"];property var modes:["contain","cover","stretch","original"];currentIndex:modes.indexOf(panel.settings.backgroundFit);onActivated:index=>panel.settings.backgroundFit=modes[index]}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Posición X del fondo (px)";explanation:"";from:-4096;to:4096;step:1;decimals:0;value:panel.settings.backgroundX;onValueEdited:v=>panel.settings.backgroundX=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Posición Y del fondo (px)";explanation:"";from:-4096;to:4096;step:1;decimals:0;value:panel.settings.backgroundY;onValueEdited:v=>panel.settings.backgroundY=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Anchura del fondo (px)";explanation:"";from:0;to:4096;step:1;decimals:0;value:panel.settings.backgroundWidth;onValueEdited:v=>panel.settings.backgroundWidth=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Altura del fondo (px)";explanation:"";from:0;to:4096;step:1;decimals:0;value:panel.settings.backgroundHeight;onValueEdited:v=>panel.settings.backgroundHeight=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Escala del fondo";explanation:"";from:0.05;to:10;step:0.05;decimals:2;value:panel.settings.backgroundScale;onValueEdited:v=>panel.settings.backgroundScale=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Rotación del fondo (°)";explanation:"";from:-180;to:180;step:1;decimals:0;value:panel.settings.backgroundRotation;onValueEdited:v=>panel.settings.backgroundRotation=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Opacidad del fondo";explanation:"";from:0;to:1;step:0.01;decimals:2;value:panel.settings.backgroundOpacity;onValueEdited:v=>panel.settings.backgroundOpacity=v}
    VisualizerSlider {Layout.fillWidth:true;controller:panel.manager.controller;label:"Radio de esquinas (px)";explanation:"";from:0;to:500;step:1;decimals:0;value:panel.settings.backgroundRadius;onValueEdited:v=>panel.settings.backgroundRadius=v}
    Label {Layout.fillWidth:true;text:"X/Y son desplazamientos respecto al reloj. Ancho/alto 0 siguen su marco. Estos controles solo transforman el fondo.";color:"#bea8b3";wrapMode:Text.WordWrap;font.pixelSize:11}
}
