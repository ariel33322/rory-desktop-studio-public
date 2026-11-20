pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "RoryTheme.js" as Theme

Column {
    id: controls
    required property var config
    required property SystemState services
    required property var backend
    required property string details
    property bool mediaVisible:true
    signal showDetails(string name)
    signal revealTop()
    readonly property bool onMain:details===""
    onDetailsChanged: {
        changeView.stop()
        opacity=config.duration>0 ? .65 : 1
        changeView.start()
    }
    NumberAnimation {id:changeView;target:controls;property:"opacity";to:1;duration:controls.config.duration}
    function cardGesture(key, secondary) {
        if(secondary)showDetails(key)
        else if(key==="wifi")services.toggleWifi()
        else if(key==="bluetooth")services.toggleBluetooth()
    }
    signal closeRequested()
    property bool legacyAvailable:false
    signal legacyRequested(string page)
    readonly property var player: Mpris.players.values.find(value=>value.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property var deviceStatus: backend.status
    objectName:"crimsonBody"
    readonly property bool sakura:config.theme==="sakura"
    function tone(original,pink){return Theme.tone(config.theme,original,pink)}
    readonly property real uiScale:Math.max(.76,Math.min(1.35,width/415))
    readonly property int circleSize:Math.floor(Math.max(36,Math.min(63*uiScale,(width-3*config.spacing)/4-4)))
    readonly property int mediaHeight:Math.round((sakura ? 157 : 167)*uiScale)
    readonly property int quickFont:Math.round(12*uiScale)
    function timecode(seconds) {
        if (!Number.isFinite(seconds)) return "—"
        const rounded=Math.max(0,Math.floor(seconds))
        return Math.floor(rounded/60)+":"+String(rounded%60).padStart(2,"0")
    }
    spacing:config.spacing
    function cards(ids) { return config.cards.filter(entry=>entry.enabled && ids.includes(entry.id)).map(entry=>entry.id) }
    function execute(key) {
        if(key==="flash"){backend.toggleFlash();return}
        const close=key==="capture" || config.closeAfterAction && ["settings","kde"].includes(key)
        backend.action(key,close ? config.duration+50 : 0)
        if(close)closeRequested()
    }
    component CardLoader: Loader {
        id: cardLoader
        required property string key
        objectName:"crimson-loader-"+key
        function secondary() {
            if(key==="volume")controls.legacyRequested("audio")
            else controls.cardGesture(key,true)
        }
        Layout.fillWidth:true
        TapHandler {
            enabled: cardLoader.key==="wifi" || cardLoader.key==="bluetooth" || cardLoader.key==="volume" && controls.legacyAvailable
            acceptedButtons:Qt.RightButton
            onTapped:cardLoader.secondary()
        }
        sourceComponent:({
            wifi:wifi,bluetooth:bluetooth,media:media,brightness:brightness,volume:volume,kde:kde
        })[key]
    }
    RowLayout {
        objectName:"crimsonConnectivity"
        width:controls.width;spacing:controls.config.spacing
        visible:controls.onMain && controls.cards(["wifi","bluetooth"]).length>0
        Repeater {
            model:controls.cards(["wifi","bluetooth"])
            delegate:CardLoader {required property string modelData;key:modelData}
        }
    }
    Loader {
        width:controls.width
        active:controls.details==="wifi" || controls.details==="bluetooth"
        visible:active
        sourceComponent:controls.details==="wifi" ? wifiDevices : bluetoothDevices
    }
    RowLayout {
        objectName:"crimsonMediaRow"
        width:controls.width;spacing:Math.min(controls.config.spacing,controls.width<300 ? 14 : 24)
        visible:controls.onMain && controls.cards(["media","brightness","volume"]).length>0
        Repeater {
            model:controls.cards(["media","brightness","volume"])
            delegate:CardLoader {
                required property string modelData
                key:modelData
                Layout.fillWidth:key==="media"
                Layout.minimumWidth:key==="media" ? 105 : 44
                Layout.preferredWidth:key==="media" ? 184 : Math.max(42,controls.width*.155)
                Layout.preferredHeight:controls.mediaHeight
            }
        }
    }
    Repeater {
        model:controls.onMain ? controls.cards(["kde"]) : []
        delegate:CardLoader {required property string modelData;key:modelData;width:controls.width}
    }
    GridLayout {
        objectName:"crimsonQuickGrid"
        visible:controls.onMain
        width:controls.width
        uniformCellWidths:true
        columns:4
        columnSpacing:controls.config.spacing
        rowSpacing:Math.round(11*controls.uiScale)
        Repeater {
            model:controls.config.quick.filter(entry=>entry.enabled)
            delegate:Item {
                id:quickSlot
                required property var modelData
                Layout.fillWidth:true
                Layout.minimumWidth:0
                Layout.preferredHeight:controls.circleSize+quickLabel.implicitHeight+7
                Label {
                    id:quickLabel
                    objectName:"crimson-label-"+quickSlot.modelData.id
                    anchors.top:quickTile.bottom
                    anchors.topMargin:5
                    anchors.left:parent.left
                    anchors.right:parent.right
                    text:quickTile.key==="record" ? "Grabar" : quickTile.text
                    color:controls.tone("#f7e4ee",Theme.text)
                    textFormat:Text.PlainText
                    horizontalAlignment:Text.AlignHCenter
                    wrapMode:Text.Wrap
                    font.pixelSize:controls.quickFont
                    Accessible.ignored:true
                }
                TapHandler {
                    enabled:quickSlot.modelData.id==="power" && controls.legacyAvailable
                    acceptedButtons:Qt.RightButton
                    onTapped:controls.legacyRequested("battery")
                }
                CrimsonTile {
                id:quickTile
                anchors.top:parent.top
                anchors.horizontalCenter:parent.horizontalCenter
                width:controls.circleSize;height:width
                readonly property string key:quickSlot.modelData.id
                objectName:"crimson-control-"+key
                readonly property var descriptions: ({
                    airplane:["✈︎","Modo avión",controls.deviceStatus.airplane,"No hay radios rfkill accesibles",controls.deviceStatus.airplaneOn],
                    dnd:["♟","No molestar",controls.deviceStatus.canDnd,"No se detectó Dunst o SwayNC",controls.deviceStatus.dnd],
                    power:["ϟ","Ahorro",controls.deviceStatus.power,"El gestor de perfiles no está disponible",PowerProfiles.profile===PowerProfile.PowerSaver],
                    record:["⏺",["active","starting"].includes(controls.deviceStatus.recordState) ? "Detener" : "Grabar",controls.deviceStatus.record && !controls.backend.recordingRequested,"Grabador no disponible o esperando respuesta",["active","starting"].includes(controls.deviceStatus.recordState)],
                    night:["☾","Noche",false,"No se detectó un mecanismo de color nocturno integrado",false],
                    capture:["⌗","Captura",controls.deviceStatus.capture,"No se encontró el script de capturas",false],
                    settings:["⚙","Configuración",controls.deviceStatus.settings,"No se encontró System Settings",false],
                    flash:["🔦︎","Linterna",!controls.backend.flashStarting,"Preparando la salida segura",controls.backend.flash]
                })
                readonly property var info:descriptions[key]
                config:controls.config
                uiScale:controls.uiScale
                compact:true
                sakuraKey:key
                iconKind:({flash:"flash",dnd:"bell",record:"record",capture:"capture"})[key] ?? ""
                symbol:info[0];text:info[1];enabled:!!info[2];selected:!!info[4]
                detail:key==="power" && controls.legacyAvailable
                    ? (enabled ? "" : info[3]+" · ")+"Clic derecho: detalles de batería"
                    : !enabled ? info[3] : key==="dnd" ? "Clic derecho para mostrar notificaciones" : text
                onClicked:controls.execute(key)
                TapHandler {
                    enabled:quickTile.key==="dnd" && !!controls.deviceStatus.canDnd
                    acceptedButtons:Qt.RightButton
                    onTapped:controls.execute("notifications")
                }
                }
            }
        }
    }
    Label {
        width:controls.width
        visible:controls.onMain && text!==""
        color:"#c4a3b4";wrapMode:Text.WordWrap;font.pixelSize:10
        text:[
            controls.cards(["brightness"]).length && !controls.backend.brightnessMethod && controls.backend.brightnessReason ? "Brillo: sin permiso o sin retroiluminación compatible." : "",
            controls.config.quick.some(e=>e.id==="airplane" && e.enabled) && !controls.deviceStatus.airplane ? "Modo avión: sin radios rfkill accesibles." : "",
            controls.config.quick.some(e=>e.id==="dnd" && e.enabled) && !controls.deviceStatus.canDnd ? "Notificaciones: requiere Dunst o SwayNC activo." : "",
            controls.config.quick.some(e=>e.id==="night" && e.enabled) ? "Noche: sin mecanismo integrado en esta instalación." : "",
            controls.config.quick.some(e=>e.id==="power" && e.enabled) && !controls.deviceStatus.power ? "Ahorro: gestor ausente, inaccesible o en conflicto." : ""
        ].filter(Boolean).join("  ")
    }
    Label {
        width:controls.width
        visible:controls.onMain && text!==""
        text:controls.backend.error || controls.deviceStatus.recordError || ""
        color:"#ffc3d3";wrapMode:Text.WordWrap;textFormat:Text.PlainText
    }
    Component {
        id:wifi
        CrimsonTile {
            objectName:"crimsonWifiCard"
            config:controls.config;uiScale:controls.uiScale;sakuraKey:"wifi";symbol:"◉";iconKind:"network"
            text:controls.services.wifi?.networks.values.find(network=>network.connected)?.name || "Wi-Fi"
            detail:!controls.services.wifi ? "Adaptador no disponible"
                : !Networking.wifiEnabled ? "Desactivado" : controls.services.wifi?.networks.values.some(network=>network.connected) ? "Conectado" : "Sin conexión"
            enabled:!!controls.services.wifi && Networking.wifiHardwareEnabled
            selected:enabled && Networking.wifiEnabled
            onClicked:controls.cardGesture("wifi",false)
        }
    }
    Component {
        id:bluetooth
        CrimsonTile {
            objectName:"crimsonBluetoothCard"
            config:controls.config;uiScale:controls.uiScale;sakuraKey:"bluetooth";symbol:"ᛒ";iconKind:"bluetooth";text:"Bluetooth";detail:controls.services.bluetoothLabel
            enabled:!!controls.services.adapter && [BluetoothAdapterState.Enabled,BluetoothAdapterState.Disabled].includes(controls.services.adapter.state);selected:controls.services.adapter?.enabled ?? false
            onClicked:controls.cardGesture("bluetooth",false)
        }
    }
    component SubmenuTitle: RowLayout {
        id: submenuTitle
        required property string title
        width:controls.width
        StudioToolButton {
            objectName:"crimsonBack"
            text:controls.sakura ? "" : "‹";Accessible.name:"Volver a controles rápidos"
            SakuraIcon {visible:controls.sakura;anchors.centerIn:parent;width:19;height:19;kind:"back"}
            onClicked:controls.showDetails("")
        }
        Label {
            Layout.fillWidth:true
            text:submenuTitle.title;color:controls.tone("#fff0f4",Theme.text)
            font.pixelSize:21;font.weight:Font.DemiBold
        }
    }
    Component {
        id:wifiDevices
        Column {
            width:controls.width
            spacing:9
            SubmenuTitle {title:"Wi-Fi"}
            NetworkPanel {
                width:parent.width
                objectName:"crimsonNetworkPanel"
                services:controls.services
                crimsonMode:true
                theme:controls.config.theme
                onRevealTop:controls.revealTop()
                onAdvanced:{
                    if(controls.legacyAvailable)controls.legacyRequested("network")
                    else if(controls.deviceStatus.settings)controls.execute("settings")
                }
            }
        }
    }
    Component {
        id:bluetoothDevices
        Column {
            width:controls.width
            spacing:9
            SubmenuTitle {title:"Bluetooth"}
            BluetoothPanel {
                width:parent.width
                objectName:"crimsonBluetoothPanel"
                services:controls.services
                crimsonMode:true
                theme:controls.config.theme
                onRevealTop:controls.revealTop()
                onAdvanced:{
                    if(controls.legacyAvailable)controls.legacyRequested("bluetooth")
                    else if(controls.deviceStatus.settings)controls.execute("settings")
                }
            }
        }
    }
    Component {
        id:media
        Rectangle {
            id:playerCard
            objectName:"crimsonMedia"
            implicitHeight:controls.mediaHeight;implicitWidth:158
            radius:controls.config.radius
            color:controls.tone("#170b12",Theme.plum)
            border.color:controls.tone(controls.config.decorative ? "#762040" : "#342a31","#704058")
            Repeater {
                model:controls.config.decorative && !controls.sakura ? [0,1,2,3] : []
                delegate:Image {
                    id:mediaCorner
                    required property int modelData
                    readonly property bool lower:modelData>=2
                    x:modelData%2 ? playerCard.width-width-1 : 1
                    y:lower ? playerCard.height-height-1 : 1
                    height:Math.round(21*controls.uiScale)
                    width:height*86/108
                    mirror:modelData%2===1
                    source:Theme.art(controls.config.theme,"floral-corner")
                    transform:Scale {origin.y:mediaCorner.height/2;yScale:mediaCorner.lower ? -1 : 1}
                    opacity:.58
                }
            }
            readonly property var player:controls.player
            readonly property real duration:player?.lengthSupported ? player.length : 0
            readonly property real elapsed:player?.positionSupported ? player.position : NaN
            readonly property int artSize:Math.round(Math.min(width*.26,68*controls.uiScale))
            Timer {
                running:controls.mediaVisible && !!playerCard.player?.isPlaying && !!playerCard.player?.positionSupported
                repeat:true;interval:1000
                onTriggered:playerCard.player.positionChanged()
            }
            ColumnLayout {
                anchors.fill:parent
                anchors.margins:Math.round(11*controls.uiScale)
                spacing:Math.round(4*controls.uiScale)
                RowLayout {
                    Layout.fillWidth:true
                    spacing:Math.round(9*controls.uiScale)
                    CrimsonArtwork {
                        Layout.preferredWidth:playerCard.artSize;Layout.preferredHeight:playerCard.artSize
                        player:playerCard.player;active:controls.mediaVisible;accent:controls.config.accent;theme:controls.config.theme
                    }
                    ColumnLayout {
                        Layout.fillWidth:true;Layout.minimumWidth:0;spacing:3
                        Label {
                            Layout.fillWidth:true
                            text:playerCard.player?.trackTitle || "Sin reproducción"
                            textFormat:Text.PlainText;color:controls.tone("#fff1f5",Theme.text)
                            font.pixelSize:Math.round(15*controls.uiScale);font.weight:Font.DemiBold
                            wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight
                            Accessible.name:text
                        }
                        Label {
                            Layout.fillWidth:true;visible:text!==""
                            text:playerCard.player?.trackArtist || ""
                            textFormat:Text.PlainText;color:"#ceacbd";elide:Text.ElideRight
                            font.pixelSize:Math.round(12*controls.uiScale)
                            Accessible.name:text
                        }
                    }
                }
                Item {Layout.fillHeight:true}
                Slider {
                    id:progress
                    Layout.fillWidth:true
                    Layout.preferredHeight:13
                    from:0;to:Math.max(1,playerCard.duration)
                    value:Number.isFinite(playerCard.elapsed) ? Math.min(to,playerCard.elapsed) : 0
                    enabled:playerCard.duration>0 && !!playerCard.player?.positionSupported && !!playerCard.player?.canSeek
                    Accessible.name:"Posición de reproducción"
                    onMoved:if(enabled)playerCard.player.position=value
                    background:Rectangle {
                        x:progress.leftPadding;y:(progress.height-height)/2
                        width:progress.availableWidth;height:5;radius:2.5;color:"#4b1b30"
                        Rectangle {width:parent.width*progress.visualPosition;height:parent.height;radius:parent.radius;color:"#e73368"}
                    }
                    handle:Item {implicitWidth:1;implicitHeight:1}
                }
                RowLayout {
                    Layout.fillWidth:true
                    Label {Layout.fillWidth:true;text:controls.timecode(playerCard.elapsed);color:"#d3b4c4";font.pixelSize:Math.round(10*controls.uiScale)}
                    Label {text:controls.timecode(playerCard.duration || NaN);color:"#d3b4c4";font.pixelSize:Math.round(10*controls.uiScale)}
                }
                RowLayout {
                    Layout.fillWidth:true;spacing:0
                    MediaButton {
                        iconKey:"shuffle";text:"⤨";Accessible.name:"Aleatorio"
                        selected:playerCard.player?.shuffle ?? false
                        visible:controls.sakura || playerCard.width>=155
                        enabled:!!playerCard.player?.canControl && !!playerCard.player?.shuffleSupported
                        onClicked:playerCard.player.shuffle=!playerCard.player.shuffle
                    }
                    MediaButton {iconKey:"previous";text:"⏮";Accessible.name:"Anterior";enabled:playerCard.player?.canGoPrevious ?? false;onClicked:playerCard.player.previous()}
                    MediaButton {
                        text:playerCard.player?.isPlaying ? "Ⅱ" : "▶"
                        iconKey:playerCard.player?.isPlaying ? "pause" : "play"
                        primary:true;Accessible.name:"Reproducir o pausar"
                        enabled:playerCard.player?.canTogglePlaying ?? false
                        onClicked:playerCard.player.togglePlaying()
                    }
                    MediaButton {iconKey:"next";text:"⏭";Accessible.name:"Siguiente";enabled:playerCard.player?.canGoNext ?? false;onClicked:playerCard.player.next()}
                    MediaButton {
                        iconKey:"repeat";text:"↻";Accessible.name:"Repetir"
                        selected:!!playerCard.player && playerCard.player.loopState!==MprisLoopState.None
                        visible:controls.sakura || playerCard.width>=155
                        enabled:!!playerCard.player?.canControl && !!playerCard.player?.loopSupported
                        onClicked:{
                            const player=playerCard.player
                            player.loopState=player.loopState===MprisLoopState.None ? MprisLoopState.Playlist
                                : player.loopState===MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                        }
                    }
                }
            }
        }
    }
    component MediaButton: Button {
        id: transport
        required property string iconKey
        property bool primary:false
        property bool selected:false
        Layout.fillWidth:true
        Layout.minimumWidth:controls.sakura ? 17 : 20
        Layout.preferredHeight:Math.round(35*controls.uiScale)
        padding:0
        contentItem:Item {
            SakuraIcon {
                visible:controls.sakura
                anchors.centerIn:parent
                width:Math.round((transport.primary ? 22 : 17)*controls.uiScale);height:width
                kind:transport.iconKey;selected:transport.primary || transport.selected;usable:transport.enabled
            }
            Text {
                visible:!controls.sakura
                anchors.fill:parent
                text:transport.text;color:transport.enabled ? "#fff1f5" : "#796473"
            font.pixelSize:Math.round((transport.primary ? 21 : 16)*controls.uiScale); horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
            }
        }
        background:Rectangle {
            radius:10
            anchors.centerIn:parent
            width:Math.min(parent.width,parent.height);height:width
            color:transport.down ? "#74304e" : transport.primary ? controls.tone("#611531","#632744")
                : transport.hovered && transport.enabled ? "#301829" : "transparent"
            border.color:transport.activeFocus || transport.selected ? controls.config.accent : "transparent"
        }
    }

    Component {
        id:brightness
        CrimsonSlider {
            config:controls.config;uiScale:controls.uiScale;symbol:"☀";title:"Brillo"
            objectName:"crimsonBrightness"
            enabled:!!controls.backend.brightnessMethod && !controls.backend.flash && !controls.backend.flashStarting
            unavailable:controls.backend.brightnessReason || "Comprobando el acceso al brillo"
            confirmedLevel:controls.backend.brightnessLevel
            changing:controls.backend.changingBrightness
            onMoved:controls.backend.setBrightness(value)
        }
    }
    Component {
        id:volume
        CrimsonSlider {
            config:controls.config;uiScale:controls.uiScale;iconKind:"audio";symbol:controls.services.audio?.muted ? "×" : "♪";title:controls.legacyAvailable ? "Volumen · clic derecho: ajustes" : "Volumen"
            enabled:!!controls.services.audio
            unavailable:"No hay una salida PipeWire activa"
            objectName:"crimsonVolume"
            confirmedLevel:controls.services.audio ? Math.min(1,controls.services.audio.volume) : -1
            onMoved:if(controls.services.audio)controls.services.audio.volume=value
        }
    }
    Component {
        id:kde
        CrimsonTile {
            objectName:"crimsonKde"
            config:controls.config;uiScale:controls.uiScale;sakuraKey:"kde";symbol:"▯";text:"KDE Connect";banner:true
            detail:controls.deviceStatus.kde>=0 ? (controls.deviceStatus.kde===0 ? "Sin dispositivos accesibles" : controls.deviceStatus.kde+" accesible(s)")
                : "Estado de conexión no disponible"
            selected:controls.deviceStatus.kde>0
            enabled:!!controls.deviceStatus.kdeApp
            onClicked:controls.execute("kde")
        }
    }
}
