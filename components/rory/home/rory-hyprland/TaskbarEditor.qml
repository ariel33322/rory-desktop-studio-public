pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "TaskbarModel.js" as Model
import "RoryTheme.js" as Theme

ColumnLayout {
    id: editor
    required property var store
    required property var studio
    readonly property var config: store.bar
    readonly property var values: config ?? Model.bar("preview","")
    readonly property var names: ({workspaces:"Espacios de trabajo",windows:"Ventanas y favoritas",
        launcher:"Lanzador",clock:"Reloj y calendario",audio:"Audio",battery:"Batería",network:"Red",
        tray:"Bandeja del sistema",media:"Multimedia"})
    readonly property string editOwner: store.profileId+"/"+(config?.id ?? "")
    onEditOwnerChanged: inputs.contextChanged()
    property string removing: ""
    property string removeProfile: ""
    property string moduleId: "workspaces"
    onVisibleChanged: if (!visible) { store.dragging=false; removing="" }
    function edit(key,value) { if (config) store.edit(store.profileId,config.id,{[key]:value}) }
    function reorder(index,offset) {
        const next=Model.copy(config.modules), at=index+offset
        if (at<0 || at>=next.length) return
        const moved=next.splice(index,1)[0]
        next.splice(at,0,moved)
        edit("modules",next)
    }
    QtObject {
        id: inputs
        signal documentChanged()
        function contextChanged() { documentChanged() }
        property var pending: []
        function beginTransaction() {}
        function endTransaction() {}
        function setInputPending(item, active) {
            pending=pending.filter(i=>i!==item)
            if(active) pending=pending.concat([item])
        }
    }

    Label {text:"Barra de tareas";color:"#eadce5";font.pixelSize:18;font.bold:true}
    Label {
        Layout.fillWidth:true
        text:editor.store.error || editor.store.associations.error
        visible:text!==""
        color:"#f6aabd"
        wrapMode:Text.WordWrap
    }
    StudioSection {
        title:"Distribución"
        Label {
            Layout.fillWidth:true
            text:"Perfil activo · "+editor.store.layout.name
            color:"#e6dde2"
        }
        StudioCombo {
            id:profileChoice
            Layout.fillWidth:true
            model:editor.store.document.layouts
            textRole:"name"
            currentIndex:editor.store.document.layouts.findIndex(p=>p.id===editor.store.profileId)
            onActivated:index=>{
                editor.store.loadProfile(model[index].id)
                currentIndex=Qt.binding(()=>editor.store.document.layouts.findIndex(p=>p.id===editor.store.profileId))
            }
        }
        StudioField {id:profileName;Layout.fillWidth:true;placeholderText:"Nombre para copiar la distribución"}
        RowLayout {
            Layout.fillWidth:true
            StudioButton {text:"Guardar copia";enabled:profileName.text.trim()!=="";onClicked:if(editor.store.saveProfile(profileName.text,false))profileName.text=""}
            StudioButton {text:"Copiar y vincular aquí";enabled:profileName.text.trim()!=="" && !!editor.store.wallpaperSettings.activeWallpaper;onClicked:if(editor.store.saveProfile(profileName.text,true))profileName.text=""}
            StudioButton {text:"Usar global";onClicked:editor.store.useGlobal()}
        }
    }
    StudioCombo {
        Layout.fillWidth:true
        model:editor.store.bars
        textRole:"name"
        currentIndex:editor.store.bars.findIndex(b=>b.id===editor.config?.id)
        onActivated:index=>{editor.store.selected=model[index].id;editor.store.dragging=false}
    }
    RowLayout {
        Layout.fillWidth:true
        StudioButton {text:"Crear barra";enabled:editor.store.ready;onClicked:editor.store.create(false)}
        StudioButton {text:"Duplicar";enabled:!!editor.config;onClicked:editor.store.create(true)}
        StudioButton {
            text:"Eliminar"
            enabled:!!editor.config
            onClicked:{editor.removing=editor.config.id;editor.removeProfile=editor.store.profileId}
        }
    }
    RowLayout {
        visible:editor.removing!=="" && editor.removeProfile===editor.store.profileId
        Label {text:"¿Eliminar esta barra?";color:"#e6dde2"}
        StudioButton {text:"Confirmar";onClicked:{editor.store.remove(editor.removeProfile,editor.removing);editor.removing=""}}
        StudioButton {text:"Cancelar";onClicked:editor.removing=""}
    }
    ColumnLayout {
        visible:!!editor.config
        Layout.fillWidth:true
        Field {key:"name";hint:"Nombre de barra"}
        StudioToggle {text:"Barra visible";checked:editor.values.enabled;onToggled:editor.edit("enabled",checked)}
        StudioSection {
            title:"Posición y dimensiones"
            StudioCombo {
                Layout.fillWidth:true
                property var ids:["top","bottom","left","right","free"]
                model:["Superior","Inferior","Izquierda","Derecha","Libre"]
                currentIndex:ids.indexOf(editor.values.edge)
                onActivated:index=>editor.edit("edge",ids[index])
            }
            StudioCombo {
                Layout.fillWidth:true
                model:["Horizontal","Vertical"]
                currentIndex:editor.values.orientation==="horizontal" ? 0 : 1
                onActivated:index=>{
                    const orientation=index===0 ? "horizontal" : "vertical"
                    const b=editor.config
                    if(b && b.orientation!==orientation)editor.store.edit(editor.store.profileId,b.id,{orientation:orientation,width:b.height,height:b.width})
                }
            }
            StudioCombo {
                Layout.fillWidth:true
                property var outputs:["",...editor.studio.screens.map(s=>s.name)]
                model:["Todas las pantallas",...outputs.slice(1)]
                currentIndex:outputs.indexOf(editor.values.output)
                onActivated:index=>editor.edit("output",outputs[index])
            }
            StudioToggle {text:"Arrastrar barra";checked:editor.store.dragging;onToggled:editor.store.dragging=checked}
            Repeater {
                model:[["width","Ancho"],["height","Alto"],["x","X (%)"],["y","Y (%)"],["margin","Margen"],["inset","Distancia al borde"],["spacing","Separación entre módulos"]]
                delegate: Numeric {required property var modelData;spec:modelData}
            }
        }
        StudioSection {
            title:"Apariencia y comportamiento"
            StudioThemePicker {title:"Tema de esta barra";theme:editor.values.theme;onChosen:value=>editor.edit("theme",value)}
            expanded:false
            Repeater {
                model:[["background","Fondo"],["border","Borde"],["iconColor","Iconos"],["textColor","Texto"],["activeColor","Selección"]]
                delegate:ColumnLayout {
                    id:colorField
                    required property var modelData
                    Layout.fillWidth:true
                    Label {text:colorField.modelData[1];color:"#e6dde2"}
                    StudioColorEditor {
                        Layout.fillWidth:true
                        controller:inputs
                        contextKey:editor.store.profileId+"/"+(editor.config?.id ?? "")+"/"+editor.values.theme+"/"+colorField.modelData[0]
                        value:Theme.taskbar(editor.values)[colorField.modelData[0]]
                        onColorEdited:c=>{
                            const key=colorField.modelData[0]
                            if(editor.values.theme==="sakura")
                                editor.edit("sakuraColors",Object.assign({},editor.values.sakuraColors,{[key]:c}))
                            else editor.edit(key,c)
                        }
                    }
                }
            }
            Repeater {
                model:[["opacity","Opacidad"],["borderWidth","Grosor del borde"],["radius","Radio de esquinas"],["padding","Separación interna"],["iconSize","Tamaño de iconos"],["textSize","Tamaño de texto"],["shadow","Sombra"],["duration","Duración de animaciones (ms; 0 desactiva)"],["delay","Demora para ocultar (ms)"],["trigger","Grosor de zona de activación"]]
                delegate:Numeric {required property var modelData;spec:modelData}
            }
            StudioToggle {text:"Solicitar desenfoque al compositor";checked:editor.values.blur;onToggled:editor.edit("blur",checked)}
            StudioToggle {text:"Ocultación automática";checked:editor.values.autohide;onToggled:editor.edit("autohide",checked)}
            StudioToggle {text:"Ocultar con ventana maximizada o en pantalla completa";checked:editor.values.hideCovered;onToggled:editor.edit("hideCovered",checked)}
            StudioButton {
                text:"Restaurar ajustes de esta barra"
                onClicked:editor.store.edit(editor.store.profileId,editor.config.id,Model.bar(editor.config.id,editor.config.name))
            }
        }
        CrimsonEditor {
            Layout.fillWidth:true
            config:editor.values.center
            controller:inputs
            owner:editor.editOwner
            onChanged:next=>editor.edit("center",next)
        }
        StudioSection {
            title:"Módulos"
            expanded:false
            Repeater {
                model:editor.values.modules
                delegate:RowLayout {
                    id:moduleRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth:true
                    StudioToggle {
                        Layout.fillWidth:true;text:editor.names[moduleRow.modelData.id];checked:moduleRow.modelData.enabled
                        onToggled:{
                            const next=Model.copy(editor.config.modules)
                            next[moduleRow.index].enabled=checked
                            editor.edit("modules",next)
                        }
                    }
                    StudioToolButton {text:"↑";enabled:moduleRow.index>0;onClicked:editor.reorder(moduleRow.index,-1)}
                    StudioToolButton {text:"↓";enabled:moduleRow.index<editor.values.modules.length-1;onClicked:editor.reorder(moduleRow.index,1)}
                }
            }
            StudioCombo {
                Layout.fillWidth:true
                model:Model.modules.map(id=>editor.names[id])
                currentIndex:Model.modules.indexOf(editor.moduleId)
                onActivated:index=>editor.moduleId=Model.modules[index]
            }
            Numeric {visible:editor.moduleId==="workspaces";spec:["workspaceGap","Separación de espacios"]}
            StudioToggle {visible:editor.moduleId==="windows";text:"Agrupar ventanas de la misma aplicación";checked:editor.values.groupWindows;onToggled:editor.edit("groupWindows",checked)}
            Field {visible:editor.moduleId==="windows";key:"favorites";hint:"IDs .desktop de favoritas separados por coma"}
            Field {visible:editor.moduleId==="launcher";key:"launcher";hint:"Comando del lanzador que ya utilizas"}
            StudioToggle {visible:editor.moduleId==="clock";text:"Mostrar fecha";checked:editor.values.date;onToggled:editor.edit("date",checked)}
            StudioToggle {visible:editor.moduleId==="clock";text:"Formato de 24 horas";checked:editor.values.hour24;onToggled:editor.edit("hour24",checked)}
            Field {visible:editor.moduleId==="clock";key:"dateFormat";hint:"Formato Qt de fecha (ddd dd MMM)"}
            Numeric {visible:editor.moduleId==="audio";spec:["volumeStep","Paso de volumen (%)"]}
            StudioToggle {visible:editor.moduleId==="battery";text:"Ocultar si no hay batería";checked:editor.values.hideBattery;onToggled:editor.edit("hideBattery",checked)}
            Field {visible:editor.moduleId==="network";key:"network";hint:"Comando opcional para abrir ajustes de red"}
            StudioToggle {visible:editor.moduleId==="media";text:"Ocultar si no hay reproducción";checked:editor.values.hideMedia;onToggled:editor.edit("hideMedia",checked)}
            Label {visible:editor.moduleId==="tray";text:"La bandeja usa los elementos disponibles del sistema.";color:"#e6dde2"}
        }
    }
    component Numeric: VisualizerSlider {
        required property var spec
        Layout.fillWidth:true
        controller:inputs
        label:spec[1]
        explanation:""
        from:Model.numbers[spec[0]][0]
        to:Model.numbers[spec[0]][1]
        decimals:spec[0]==="opacity" ? 2 : 0
        value:editor.values[spec[0]]
        onValueEdited:v=>editor.edit(spec[0],v)
    }
    component Field: ColumnLayout {
        id:field
        required property string key
        required property string hint
        Layout.fillWidth:true
        Label {text:field.hint;color:"#e6dde2";Layout.fillWidth:true;wrapMode:Text.WordWrap}
        StudioField {
            id:entry
            Layout.fillWidth:true
            text:editor.values[field.key]
            property string owner: ""
            property bool dirty: false
            onTextEdited: {
                if (!dirty) owner=editor.editOwner
                dirty=true
            }
            onEditingFinished: {
                if (dirty && owner===editor.editOwner && (field.key!=="name" || text.trim()))
                    editor.edit(field.key,text.trim())
                dirty=false
                text=Qt.binding(()=>editor.values[field.key])
            }
            Connections {
                target:inputs
                function onDocumentChanged() { entry.dirty=false;entry.text=Qt.binding(()=>editor.values[field.key]) }
            }
        }
    }
}
