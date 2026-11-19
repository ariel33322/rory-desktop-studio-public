pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:control
 objectName:"colorEditor"
 required property var controller
 required property string value
 property string contextKey:""
 property real hue:0
 property real saturation:1
 property real brightness:1
 property bool choosing:false
 property string inputError:""
 signal colorEdited(string color)
 function hex(n){return Math.round(n*255).toString(16).padStart(2,"0")}
 function parse(text){
  text=String(text).trim();if(/^#?[0-9a-fA-F]{6}$/.test(text))return (text[0]==="#" ? text : "#"+text).toLowerCase()
  const match=/^(?:rgb\s*\(\s*)?(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*\)?$/i.exec(text)
  if(match){const rgb=match.slice(1).map(Number);if(rgb.every(v=>v>=0 && v<=255))return "#"+rgb.map(v=>v.toString(16).padStart(2,"0")).join("")}

  return ""
 }
 function sync(){const c=parse(value);if(!c)return;const r=parseInt(c.slice(1,3),16)/255,g=parseInt(c.slice(3,5),16)/255,b=parseInt(c.slice(5,7),16)/255,max=Math.max(r,g,b),min=Math.min(r,g,b),d=max-min;brightness=max;saturation=max===0 ? 0 : d/max;if(d>0){let h=max===r ? (g-b)/d+(g<b ? 6 : 0) : max===g ? (b-r)/d+2 : (r-g)/d+4;hue=h/6}}
 function applyHsv(){const h=hue*6,i=Math.floor(h),f=h-i,p=brightness*(1-saturation),q=brightness*(1-f*saturation),t=brightness*(1-(1-f)*saturation),rgb=[[brightness,t,p],[q,brightness,p],[p,brightness,t],[p,q,brightness],[t,p,brightness],[brightness,p,q]][i%6];colorEdited("#"+rgb.map(hex).join(""))}
 onValueChanged:{field.cancel();if(!choosing)sync()}
 onContextKeyChanged:{field.cancel();choosing=false;controller.endTransaction();sync()}
 RowLayout {Layout.fillWidth:true
  Rectangle {Layout.preferredWidth:24;Layout.preferredHeight:24;radius:5;color:control.value;border.color:"#8c6575"}
  StudioField {
   id:field;objectName:"layerColor";Layout.fillWidth:true;Layout.minimumWidth:70;maximumLength:24;text:control.value;selectByMouse:true;Accessible.name:"Color HEX o RGB"
   property bool dirty:false
   property string owner:""
   property string base:""
   function pending(value){if(dirty===value)return;dirty=value;if(control.controller.setInputPending)control.controller.setInputPending(field,value)}
   function cancel(){control.inputError="";pending(false);text=control.value;owner=control.contextKey;base=control.value}
   function finishForProfile(){if(!dirty)return;const c=control.parse(text),apply=c && owner===control.contextKey && base===control.value && control.enabled && control.visible;control.inputError=c ? "" : "Color inválido. Usa #RRGGBB, rgb(R,G,B) o tres canales 0–255.";pending(false);if(apply){control.controller.beginTransaction();control.colorEdited(c);control.controller.endTransaction()}text=control.value}
   onActiveFocusChanged:if(activeFocus){owner=control.contextKey;base=control.value}
   onTextEdited:{control.inputError="";pending(true)}
   onEditingFinished:finishForProfile()
   Component.onDestruction:pending(false)
   Keys.onEscapePressed:event=>{cancel();event.accepted=true}
  }
 }
 Text {Layout.fillWidth:true;visible:control.inputError!=="";text:control.inputError;wrapMode:Text.WordWrap;color:"#e6a6bc";font.pixelSize:11}
 StudioSection {title:"Selector de color y paleta";expanded:false
  Rectangle {Layout.fillWidth:true;Layout.preferredHeight:110;radius:5;clip:true
   Canvas {id:colorCanvas;anchors.fill:parent;onPaint:{const c=getContext("2d");c.fillStyle=Qt.hsla(control.hue,1,.5,1);c.fillRect(0,0,width,height);const w=c.createLinearGradient(0,0,width,0);w.addColorStop(0,"white");w.addColorStop(1,"rgba(255,255,255,0)");c.fillStyle=w;c.fillRect(0,0,width,height);const b=c.createLinearGradient(0,0,0,height);b.addColorStop(0,"rgba(0,0,0,0)");b.addColorStop(1,"black");c.fillStyle=b;c.fillRect(0,0,width,height)}}
   Rectangle {x:control.saturation*(parent.width-10);y:(1-control.brightness)*(parent.height-10);width:10;height:10;radius:5;color:"transparent";border.color:"white"}
   MouseArea {anchors.fill:parent;function choose(mouse){control.saturation=Math.max(0,Math.min(1,mouse.x/width));control.brightness=1-Math.max(0,Math.min(1,mouse.y/height));control.applyHsv()}
    onPressed:mouse=>{control.controller.beginTransaction();control.choosing=true;choose(mouse)}
    onPositionChanged:mouse=>{if(pressed)choose(mouse)}
    onReleased:{control.choosing=false;control.controller.endTransaction()}
    onCanceled:{control.choosing=false;control.controller.endTransaction()}}
  }
  VisualizerSlider {Layout.fillWidth:true;controller:control.controller;label:"Tono";explanation:"";from:0;to:359;decimals:1;value:control.hue*359;suffix:"°";onInteractionStarted:control.choosing=true;onInteractionFinished:control.choosing=false;onValueEdited:v=>{control.hue=v/359;control.applyHsv()}}
  Flow {Layout.fillWidth:true;spacing:6
   Repeater {model:[{name:"Carmesí",value:"#e73858"},{name:"Burdeos",value:"#a51635"},{name:"Rosa",value:"#f15b78"},{name:"Cobre",value:"#dc7b37"},{name:"Gris rosado",value:"#d7c8cf"},{name:"Blanco",value:"#ffffff"},{name:"Rosa pálido",value:"#ff9eb2"},{name:"Blanco lunar",value:"#fff4f6"},{name:"Violeta",value:"#bb78ff"},{name:"Azul hielo",value:"#73dfff"}]
    delegate:StudioToolButton {id:swatch;required property var modelData;text:"●";Accessible.name:"Color "+modelData.name;ToolTip.visible:hovered;ToolTip.text:modelData.name;contentItem:Text {text:"●";color:swatch.modelData.value;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}onClicked:control.colorEdited(modelData.value)}
   }
  }
 }
 Connections {target:control;function onHueChanged(){colorCanvas.requestPaint()}}
 Connections {target:control.controller;ignoreUnknownSignals:true;function onRestoringChanged(){if(control.controller.restoring)field.cancel()}}
 Component.onCompleted:sync()
}
