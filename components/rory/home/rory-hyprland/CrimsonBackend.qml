pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend
    width:0;height:0;visible:false
    required property string output
    required property bool open
    readonly property string script: Quickshell.shellPath("scripts/crimson-control.py")
    property var status: ({})
    property string error: ""
    property real pendingLevel: -1
    property real brightnessLevel: -1
    property string brightnessMethod: ""
    property string brightnessReason: ""
    property int lightGeneration: 0
    readonly property bool changingBrightness: adjust.running || pendingLevel>=0
    function readBrightness() {
        if (!lightRead.running && !lightCheck.running && !changingBrightness) {
            lightRead.generation=lightGeneration
            lightRead.exec(["python3",script,"brightness-read",output])
        }
    }
    function checkBrightness() {
        if(!open || lightCheck.running || flash || flashStarting)return
        lightCheck.generation=lightGeneration
        lightCheck.exec(["python3",script,"brightness-check",output])
    }
    onOutputChanged: {
        ++lightGeneration
        pendingLevel=-1
        brightnessLevel=-1
        brightnessMethod=""
        if(lightRead.running)lightRead.running=false
        if(open)Qt.callLater(checkBrightness)
    }
    property bool flash: false
    property bool flashStarting: false
    property bool recordingRequested: false
    property string pendingAction: ""
    function refresh() { if (!probe.running) probe.running=true }
    function setBrightness(value) {
        if(!brightnessMethod)return
        pendingLevel=value
        if(!brightnessDelay.running)brightnessDelay.start()
    }
    function action(id, delay) {
        if (act.running || pendingAction!=="") return
        error=""
        pendingAction=id
        actionDelay.interval=delay
        actionDelay.restart()
        if(id==="record"){recordingRequested=true;recordDelay.restart()}
    }
    function toggleFlash() {
        if(flash || flashStarting){stopFlash();return}
        error=""
        flashStarting=true
        guardian.running=true
        startupLimit.restart()
    }
    function stopFlash() {
        flash=false
        flashStarting=false
        startupLimit.stop()
        exposureLimit.stop()
        if(guardian.running)guardian.write("STOP\n")
    }
    onOpenChanged:if(open){error="";refresh();checkBrightness()}
    Component.onCompleted:if(open){refresh();checkBrightness()}
    Timer {running:backend.open;repeat:true;interval:500;onTriggered:backend.readBrightness()}
    Timer {running:backend.open;repeat:true;interval:1200;onTriggered:backend.refresh()}
    Timer {id:recordDelay;interval:1600;onTriggered:{backend.recordingRequested=false;backend.refresh()}}
    Timer {id:startupLimit;interval:5000;onTriggered:{backend.error="La linterna no confirmó el arranque";backend.stopFlash();guardian.running=false}}
    Timer {id:exposureLimit;interval:110000;onTriggered:backend.stopFlash()}
    Timer {
        id:brightnessDelay
        interval:75
        onTriggered:{
            if(backend.pendingLevel<0)return
            if(adjust.running){restart();return}
            adjust.generation=backend.lightGeneration
            adjust.command=["python3",backend.script,"brightness",backend.output,String(backend.pendingLevel),backend.brightnessMethod]
            adjust.running=true
            backend.pendingLevel=-1
        }
    }
    Timer {
        id:actionDelay
        onTriggered:{
            act.command=["python3",backend.script,"action",backend.pendingAction]
            backend.pendingAction=""
            act.running=true
        }
    }

    Process {
        id:probe
        command:["python3",backend.script,"probe",backend.output]
        stdout:StdioCollector {
            onStreamFinished: {
                try { backend.status=JSON.parse(text) }
                catch(e) { if(backend.open)backend.error="No se pudo consultar el estado de los servicios" }
            }
        }
    }
    Process {
        id:lightCheck
        property int generation: -1
        stdout:StdioCollector {id:checkedLight}
        onExited: code=>{
            if(lightCheck.generation!==backend.lightGeneration){Qt.callLater(backend.checkBrightness);return}
            try {
                const result=JSON.parse(checkedLight.text)
                backend.brightnessLevel=result.level
                backend.brightnessMethod=result.method
                backend.brightnessReason=result.reason
            } catch (_) {
                backend.brightnessMethod=""
                backend.brightnessReason="No se pudo verificar el acceso al brillo"
            }
        }
    }
    Process {
        id:lightRead
        property int generation: -1
        stdout:StdioCollector {
            onStreamFinished:{
                if(lightRead.generation===backend.lightGeneration && !backend.changingBrightness) {
                    try {backend.brightnessLevel=JSON.parse(text).level} catch (_) {}
                }
            }
        }
    }
    Process {
        id:adjust
        property int generation: -1
        stdout:StdioCollector {id:adjustedLight}
        stderr:StdioCollector {id:adjustError}
        onExited:(code)=>{
            if(adjust.generation!==backend.lightGeneration)return
            if(code!==0){
                backend.error=adjustError.text.trim() || "No se pudo ajustar el brillo"
                backend.brightnessMethod=""
                backend.pendingLevel=-1
                Qt.callLater(backend.checkBrightness)
            } else {
                try {backend.brightnessLevel=JSON.parse(adjustedLight.text).level} catch (_) {}
            }
            if(backend.pendingLevel<0)Qt.callLater(backend.readBrightness)
        }
    }
    Process {
        id:act
        stderr:StdioCollector {id:actionError}
        onExited:(code)=>{
            if(code!==0)backend.error=actionError.text.trim() || "La acción falló"
            backend.refresh()
        }
    }
    Process {
        id:guardian
        command:["python3",backend.script,"flash",backend.output]
        stdinEnabled:true
        stdout:SplitParser {
            onRead:line=>{
                if(line.trim()!=="READY" || !backend.flashStarting)return
                startupLimit.stop()
                backend.flashStarting=false
                backend.flash=true
                exposureLimit.restart()
            }
        }
        stderr:StdioCollector {id:guardError}
        onExited:(code)=>{
            backend.flash=false
            backend.flashStarting=false
            startupLimit.stop()
            exposureLimit.stop()
            if(code!==0)backend.error=guardError.text.trim() || "Falló la protección de la linterna"
            if(backend.open){
                backend.refresh()
                Qt.callLater(backend.readBrightness)
                if(!backend.brightnessMethod)Qt.callLater(backend.checkBrightness)
            }
        }
    }
}
