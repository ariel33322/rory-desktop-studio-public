pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "WallpaperIdentity.js" as Wallpaper

ColumnLayout {
    id:panel
    required property var manager
    property string editingUrl:""
    property string clockId:""
    property string audioId:""
    property string message:""
    readonly property var clockProfiles:manager.clockManager.orderedProfiles
    readonly property var audioProfiles:manager.audioManager.orderedProfiles
    function edit(url) {
        if(!manager.ready)return
        try {
            editingUrl=Wallpaper.normalize(url)
            const rule=manager.associationRule(editingUrl)
            clockId=rule.clockProfile;audioId=rule.audioProfile
            message=""
        }catch(e){message=String(e.message || e)}
    }
    function save() {
        const saved=manager.saveAssociation(editingUrl,rule())
        if(saved)message="Asociación guardada"
        return saved
    }
    function rule() {return {clockProfile:clockId,audioProfile:audioId}}
    FileDialog {id:picker;title:"Fondo para asociar";nameFilters:["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp *.avif *.gif *.svg)"];onAccepted:panel.edit(selectedFile)}
    Label {text:"Perfiles vinculados al fondo";font.pixelSize:18;font.bold:true;color:"#eadce5";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Flow {Layout.fillWidth:true;spacing:6
        StudioButton {text:"Fondo activo";enabled:panel.manager.ready;onClicked:panel.edit(panel.manager.wallpaperSettings.activeWallpaper)}
        StudioButton {text:"Elegir imagen para vincular…";onClicked:picker.open()}
    }
    StudioCombo {
        Layout.fillWidth:true
        property var urls:panel.manager.allKeys()
        model:urls.map(url=>Wallpaper.label(url))
        currentIndex:urls.indexOf(panel.editingUrl)
        onActivated:index=>panel.edit(urls[index])
    }
    Label {Layout.fillWidth:true;text:panel.editingUrl || "Selecciona el fondo que deseas asociar.";textFormat:Text.PlainText;color:"#bea8b3";wrapMode:Text.WrapAnywhere}
    Label {text:"Perfil del reloj";color:"#ded5da"}
    StudioCombo {objectName:"associationClockProfile";Layout.fillWidth:true;model:["Sin perfil vinculado"].concat(panel.clockProfiles.map(p=>p.name));currentIndex:panel.clockId ? panel.clockProfiles.findIndex(p=>p.id===panel.clockId)+1 : 0;onActivated:index=>panel.clockId=index>0 ? panel.clockProfiles[index-1].id : ""}
    Label {text:"Perfil del visualizador";color:"#ded5da"}
    StudioCombo {objectName:"associationAudioProfile";Layout.fillWidth:true;model:["Sin perfil vinculado"].concat(panel.audioProfiles.map(p=>p.name));currentIndex:panel.audioId ? panel.audioProfiles.findIndex(p=>p.id===panel.audioId)+1 : 0;onActivated:index=>panel.audioId=index>0 ? panel.audioProfiles[index-1].id : ""}
    Label {Layout.fillWidth:true;visible:(panel.clockId!=="" && panel.clockProfiles.every(p=>p.id!==panel.clockId)) || (panel.audioId!=="" && panel.audioProfiles.every(p=>p.id!==panel.audioId));text:"La asociación referencia un perfil eliminado. Elige un destino disponible antes de aplicarla.";color:"#efb0c0";wrapMode:Text.WordWrap}
    Flow {Layout.fillWidth:true;spacing:6
        StudioButton {objectName:"saveWallpaperAssociation";text:"Guardar asociación";enabled:panel.editingUrl!=="" && panel.manager.ready;onClicked:panel.save()}
        StudioButton {objectName:"deleteWallpaperAssociation";text:"Eliminar asociación";enabled:panel.editingUrl!=="" && panel.manager.ready;onClicked:removeDialog.open()}
    }
    StudioSection {
        title:"Perfiles predeterminados"
        enabled:panel.manager.ready
        Repeater {
            model:[
                {title:"Reloj", profile:"clockProfile", flag:"clockDefaultEnabled"},
                {title:"Visualizador", profile:"audioProfile", flag:"audioDefaultEnabled"}
            ]
            delegate:ColumnLayout {
                id:defaults
                required property var modelData
                Layout.fillWidth:true
                readonly property var saved:panel.manager.document?.defaults
                readonly property var profiles:modelData.profile==="clockProfile" ? panel.clockProfiles : panel.audioProfiles
                readonly property int selected:profiles.findIndex(profile=>profile.id===saved?.[modelData.profile])
                function update(field,value) {
                    const rule=Object.assign({},saved,{[field]:value})
                    if (!rule[modelData.profile]) rule[modelData.flag]=false
                    panel.manager.saveDefaults(rule,false)
                }
                Label {text:defaults.modelData.title;color:"#ded5da"}
                StudioToggle {
                    objectName:defaults.modelData.flag
                    text:"Usar perfil predeterminado"
                    enabled:defaults.selected>=0
                    checked:defaults.saved?.[defaults.modelData.flag] ?? false
                    onToggled:defaults.update(defaults.modelData.flag,checked)
                }
                StudioCombo {
                    objectName:defaults.modelData.profile+"Default"
                    Layout.fillWidth:true
                    model:["Seleccionar perfil"].concat(defaults.profiles.map(profile=>profile.name))
                    currentIndex:defaults.selected+1
                    onActivated:index=>defaults.update(defaults.modelData.profile,index>0 ? defaults.profiles[index-1].id : "")
                }
            }
        }
        StudioButton {
            text:"Capturar referencia de borradores"
            onClicked:{
                if (panel.manager.saveDefaults(panel.manager.document.defaults,true))
                    panel.message="Referencia de borradores guardada"
            }
        }
    }
    readonly property QtObject dialogs:QtObject {
      readonly property Dialog removeUi:Dialog {
        id:removeDialog
        parent:panel.Overlay.overlay
        modal:true;title:"Eliminar asociación";standardButtons:Dialog.Ok | Dialog.Cancel
        x:parent ? (parent.width-width)/2 : 0;y:parent ? (parent.height-height)/2 : 0
        width:Math.min(440,parent ? parent.width-24 : 440)
        implicitHeight:220
        height:parent ? Math.min(220,Math.max(140,parent.height-24)) : 220
        contentItem:Label {text:"Se eliminará el vínculo de este wallpaper. Los perfiles y el fondo actual se conservan.";color:"#ded5da";wrapMode:Text.WordWrap}
        background:Rectangle {color:"#292229";radius:9;border.color:"#975069"}
        onAccepted:if(panel.manager.removeAssociation(panel.editingUrl))panel.message="Asociación eliminada"
    }
    }
    Label {Layout.fillWidth:true;visible:text!=="";text:panel.message || panel.manager.error;color:"#dfb4c5";wrapMode:Text.WordWrap}
    Label {Layout.fillWidth:true;text:"Guardar un vínculo no cambia ni sobrescribe perfiles. Aplicar pide una decisión si hay cambios sin guardar. Los vínculos anteriores del visualizador siguen disponibles.";color:"#bea8b3";font.pixelSize:11;wrapMode:Text.WordWrap}
    Connections {target:panel.manager;function onReadyChanged(){if(panel.manager.ready && !panel.editingUrl)panel.edit(panel.manager.wallpaperSettings.activeWallpaper)}}
    Component.onCompleted:if(manager.ready)edit(manager.wallpaperSettings.activeWallpaper)
}
