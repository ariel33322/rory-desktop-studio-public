pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: editor
    required property ShellScreen modelData
    required property ClockSettings settings
    required property ClockProfileManager profileManager
    property var studio: null
    property var associations: null
    property int category: 0
    property real panelWidth: 520
    property real panelHeight: 850
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    visible: settings.editorOpen && settings.editorScreen === modelData
    color: "transparent"
    WlrLayershell.namespace: "rory-clock-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: card
        Region { item: card.Overlay.overlay && card.Overlay.overlay.visible ? card.Overlay.overlay : null }
    }
    function finish() { card.forceActiveFocus(); profileManager.controller.finishPendingInputs() }
    function closeEditor() { finish(); settings.editorOpen=false }
    Rectangle {
        id: card
        x: Math.max(12, editor.width-width-24); y: 24
        width: Math.max(1, Math.min(editor.panelWidth, editor.width-24))
        height: Math.max(1, Math.min(editor.panelHeight, editor.height-48))
        radius: 10; color: "#f51c191e"; border.color: "#6b3e4d"
        MouseArea {
            x:12; y:8; width:Math.max(1,parent.width-60); height:34
            drag.target:card
            drag.minimumX:0; drag.maximumX:Math.max(0,editor.width-card.width)
            drag.minimumY:0; drag.maximumY:Math.max(0,editor.height-card.height)
            cursorShape:Qt.SizeAllCursor
            z:2
        }
        MouseArea {
            anchors.right:parent.right; anchors.bottom:parent.bottom
            width:16; height:16; z:3; cursorShape:Qt.SizeFDiagCursor
            property point start
            property real startWidth:0
            property real startHeight:0
            onPressed:event=>{start=mapToItem(null,event.x,event.y);startWidth=card.width;startHeight=card.height}
            onPositionChanged:event=>{
                if(!pressed)return
                const point=mapToItem(null,event.x,event.y)
                editor.panelWidth=Math.max(340,Math.min(editor.width-card.x,startWidth+point.x-start.x))
                editor.panelHeight=Math.max(300,Math.min(editor.height-card.y,startHeight+point.y-start.y))
            }
            Text {anchors.centerIn:parent;text:"◢";color:"#b16e84"}
        }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth:true; text:"Rory Desktop Studio · Reloj";color:"#f0e6eb";font.pixelSize:16;font.bold:true }
                StudioToolButton {text:"×";onClicked:editor.closeEditor()}
            }
            StudioNavigation {Layout.fillWidth:true;studio:editor.studio;targetScreen:editor.modelData;destination:"clock"}
            StudioProfileBar {Layout.fillWidth:true;manager:editor.profileManager}
            StudioCombo {Layout.fillWidth:true;model:["Geometría","Tipografía y color","Contenido","Fondo"];currentIndex:editor.category;onActivated:index=>{editor.finish();editor.category=index}}
            ScrollView {
                id: scroll
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ColumnLayout {
                    width:scroll.availableWidth;spacing:12
                    Label {Layout.fillWidth:true;visible:text!=="";text:editor.profileManager.error;color:"#efb0c0";wrapMode:Text.WordWrap}
                    StudioSection {title:"Cambios de perfil sin guardar";visible:!!editor.profileManager.pendingChange
                        Label {Layout.fillWidth:true;text:"Guardar, descartar o conservar los cambios antes de cargar otro perfil.";color:"#dfc8d3";wrapMode:Text.WordWrap}
                        Flow {Layout.fillWidth:true;spacing:6
                            StudioButton {text:"Guardar y cambiar";onClicked:editor.profileManager.resolvePending("save")}
                            StudioButton {text:"Descartar y cambiar";onClicked:editor.profileManager.resolvePending("discard")}
                            StudioButton {text:"Cancelar";onClicked:editor.profileManager.resolvePending("cancel")}
                        }
                    }
                    StudioSection {title:"Eliminar perfil";visible:editor.profileManager.pendingDelete!==""
                        Label {Layout.fillWidth:true;text:"¿Eliminar «"+editor.profileManager.profileName(editor.profileManager.pendingDelete)+"»? La configuración actual del escritorio se conserva aunque se elimine el perfil.";textFormat:Text.PlainText;color:"#dfc8d3";wrapMode:Text.WordWrap}
                        RowLayout {StudioButton {text:"Eliminar";onClicked:editor.profileManager.confirmDelete(true)} StudioButton {text:"Cancelar";onClicked:editor.profileManager.confirmDelete(false)}}
                    }
                    StudioSection {title:"Reemplazar perfil";visible:editor.profileManager.pendingSave!==""
                        Label {Layout.fillWidth:true;text:"¿Reemplazar «"+editor.profileManager.profileName(editor.profileManager.pendingSave)+"»?";textFormat:Text.PlainText;color:"#dfc8d3";wrapMode:Text.WordWrap}
                        RowLayout {StudioButton {text:"Reemplazar";onClicked:editor.profileManager.confirmSave(true)} StudioButton {text:"Cancelar";onClicked:editor.profileManager.confirmSave(false)}}
                    }
                    StudioSection {title:"Geometría";visible:editor.category===0
                        StudioToggle {
                            objectName:"clockVisibility"
                            visible:editor.associations!==null
                            text:"Reloj visible en este fondo"
                            checked:editor.associations?.clockVisible ?? false
                            onToggled:editor.associations.setClockVisibility(checked)
                        }
                        StudioButton {
                            Layout.fillWidth:true;text:"Ajustar con puntero"
                            onClicked:{editor.settings.pointerEditMode=true;editor.closeEditor()}
                        }
                        Label {Layout.fillWidth:true;text:"Arrastra para mover. Usa la esquina para redimensionar, Mayús para escalar y clic derecho para volver.";color:"#bea8b3";wrapMode:Text.WordWrap}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Posición horizontal (%)";from:0;to:100;explanation:"";step:0.1;decimals:1;value:editor.settings.leftPercent*100;onValueEdited:v=>{editor.settings.leftPercent=v/100}}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Posición vertical (%)";from:0;to:100;explanation:"";step:0.1;decimals:1;value:editor.settings.topPercent*100;onValueEdited:v=>{editor.settings.topPercent=v/100}}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Anchura (px)";from:40;to:4096;explanation:"";step:1;decimals:0;value:editor.settings.widgetWidth;onValueEdited:v=>{editor.settings.customWidth=v}}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Altura (px)";from:40;to:4096;explanation:"";step:1;decimals:0;value:editor.settings.widgetHeight;onValueEdited:v=>{editor.settings.customHeight=v}}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Rotación (°)";from:-180;to:180;explanation:"";step:1;decimals:0;value:editor.settings.clockRotation;onValueEdited:v=>{editor.settings.clockRotation=v}}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Opacidad";from:0;to:1;explanation:"";step:0.01;decimals:2;value:editor.settings.widgetOpacity;onValueEdited:v=>{editor.settings.widgetOpacity=v}}
                        Label {text:"Alineación horizontal";color:"#ded5da"}
                        StudioCombo {Layout.fillWidth:true;model:["Izquierda","Centro","Derecha"];currentIndex:editor.settings.horizontalAlignment;onActivated:index=>editor.settings.horizontalAlignment=index}
                        Label {text:"Alineación vertical";color:"#ded5da"}
                        StudioCombo {Layout.fillWidth:true;model:["Arriba","Centro","Abajo"];currentIndex:editor.settings.verticalAlignment;onActivated:index=>editor.settings.verticalAlignment=index}
                    }
                    StudioSection {title:"Tipografía y color";visible:editor.category===1
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Tamaño de la hora (px)";from:8;to:300;explanation:"";step:1;decimals:0;value:editor.settings.timeSize;onValueEdited:v=>{editor.settings.timeSize=v}}
                        Label {text:"Familia de fuente";color:"#ded5da"}
                        StudioField {Layout.fillWidth:true;text:editor.settings.fontFamily;onTextEdited:editor.settings.fontFamily=text}
                        StudioCombo {Layout.fillWidth:true;model:["Fina","Ligera","Normal","Media","Seminegrita","Negrita","Negra"];property var weights:[100,300,400,500,600,700,900];currentIndex:weights.indexOf(editor.settings.fontWeight);onActivated:index=>editor.settings.fontWeight=weights[index]}
                        Label {text:"Color del texto · HEX / RGB";color:"#ded5da"}
                        StudioColorEditor {Layout.fillWidth:true;controller:editor.profileManager.controller;value:editor.settings.textColor;contextKey:editor.profileManager.activeId+"/textColor";onColorEdited:c=>editor.settings.textColor=c}
                        StudioToggle {text:"Contorno del texto";checked:editor.settings.outlineEnabled;onToggled:editor.settings.outlineEnabled=checked}
                        ColumnLayout {
                            Layout.fillWidth:true
                            visible:editor.settings.outlineEnabled
                            Label {text:"Color del contorno · HEX / RGB";color:"#ded5da"}
                            StudioColorEditor {
                                Layout.fillWidth:true
                                controller:editor.profileManager.controller
                                value:editor.settings.outlineColor || "#ffffff"
                                contextKey:editor.profileManager.activeId+"/outlineColor"
                                onColorEdited:c=>editor.settings.outlineColor=c
                            }
                            StudioButton {
                                text:"Usar colores originales del contorno"
                                visible:editor.settings.outlineColor!==""
                                onClicked:editor.settings.outlineColor=""
                            }
                            Label {visible:editor.settings.outlineColor==="";text:"Colores originales por elemento";color:"#bea8b3"}
                            VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Grosor del contorno";explanation:"";from:0.5;to:8;step:0.1;decimals:1;suffix:" px";value:editor.settings.outlineWidth;onValueEdited:v=>editor.settings.outlineWidth=v}
                            VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Opacidad del contorno";explanation:"";from:0;to:100;step:1;suffix:" %";value:editor.settings.outlineOpacity*100;onValueEdited:v=>editor.settings.outlineOpacity=v/100}
                        }
                        Label {text:"Acento · HEX / RGB";color:"#ded5da"}
                        StudioColorEditor {Layout.fillWidth:true;controller:editor.profileManager.controller;value:editor.settings.accent;contextKey:editor.profileManager.activeId+"/accent";onColorEdited:c=>editor.settings.accent=c}
                    }
                    StudioSection {title:"Contenido";visible:editor.category===2
                        StudioField {Layout.fillWidth:true;placeholderText:"Título";text:editor.settings.title;onTextEdited:editor.settings.title=text}
                        StudioField {Layout.fillWidth:true;placeholderText:"Firma";text:editor.settings.signature;onTextEdited:editor.settings.signature=text}
                        StudioToggle {text:"Formato de 24 horas";checked:editor.settings.use24Hour;onToggled:editor.settings.use24Hour=checked}
                        StudioToggle {text:"Mostrar segundos";checked:editor.settings.showSeconds;onToggled:editor.settings.showSeconds=checked}
                        StudioToggle {text:"Mostrar fecha";checked:editor.settings.showDate;onToggled:editor.settings.showDate=checked}
                        VisualizerSlider {Layout.fillWidth:true;controller:editor.profileManager.controller;label:"Separación entre elementos (px)";from:0;to:100;explanation:"";step:1;decimals:0;value:editor.settings.elementSpacing;onValueEdited:v=>{editor.settings.elementSpacing=v}}
                    }
                    StudioSection {title:"Fondo";visible:editor.category===3
                        ClockBackgroundPanel {Layout.fillWidth:true;settings:editor.settings;manager:editor.profileManager}
                    }
                    Label {Layout.fillWidth:true;text:"Vista previa en el escritorio · ajustes actuales guardados automáticamente. Usa ⋯ → Guardar para actualizar el perfil.";color:"#bea8b3";font.pixelSize:11;wrapMode:Text.WordWrap}
                }
            }
        }
    }
    Shortcut {sequence:"Escape";context:Qt.WindowShortcut;onActivated:editor.closeEditor()}
}
