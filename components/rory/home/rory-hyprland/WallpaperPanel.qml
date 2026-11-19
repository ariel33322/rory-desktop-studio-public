pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "WallpaperIdentity.js" as WallpaperIdentity

Item {
    id: panel
    required property WallpaperSettings settings
    property bool selectionOnly:false
    property bool showStudioActions:true
    property bool showConfiguration:false
    signal imageSelected(string url)
    implicitWidth: 302
    implicitHeight: content.implicitHeight
    readonly property string defaultFolder: Quickshell.env("HOME") + "/Imágenes/Wallpaper"
    readonly property string folderUrl: settings.galleryFolder || localUrl(defaultFolder)
    readonly property string wallpaperFolder: localPath(folderUrl)
    property string folderAtOpen: ""
    property string folderMessage: ""
    readonly property var supportedExtensions: [
        "3fr", "apng", "arw", "avif", "bmp", "cr2", "cr3", "dcr", "dds", "dib", "dng", "erf", "exr", "fff", "gif", "hdr", "heic", "heif", "icns", "ico", "iff", "iiq", "j2c", "j2k", "jfif", "jng", "jp2", "jpe", "jpeg", "jpf", "jpg", "jpm", "jpx", "jxl", "k25", "kdc", "kra", "lbm", "mef", "mng", "mos", "mrw", "nef", "nrw", "orf", "pbm", "pcx", "pef", "pfm", "pgm", "pic", "png", "ppm", "psd", "pxr", "qoi", "raf", "ras", "raw", "rgb", "rgba", "rw2", "rwl", "sct", "sr2", "srf", "srw", "svg", "svgz", "tga", "tif", "tiff", "tim", "wbmp", "webp", "xbm", "xcf", "xpm", "x3f"
    ]
    property string selectionMessage: ""
    property var gallery: []
    readonly property var visualizerColors: [
        { name: "Carmesí", value: "#e73858" },
        { name: "Rosa pálido", value: "#ff9eb2" },
        { name: "Blanco lunar", value: "#fff4f6" },
        { name: "Violeta", value: "#bb78ff" },
        { name: "Azul hielo", value: "#73dfff" }
    ]
    function localUrl(path) { return WallpaperIdentity.normalize(path,true) }
    function localPath(url) {
        const value = url.toString()
        return value.startsWith("file://") ? decodeURIComponent(value.replace(/^file:\/\//, "")) : value
    }
    function sameFolder(first, second) {
        const firstPath = localPath(first).replace(/\/+$/, "") || "/"
        const secondPath = localPath(second).replace(/\/+$/, "") || "/"
        return firstPath === secondPath
    }
    function refreshGallery() {
        gallery = []
        if (galleryScanner.running) galleryScanner.running = false
        Qt.callLater(() => galleryScanner.running = true)
    }
    function openFolderPicker() {
        folderAtOpen = folderUrl
        folderMessage = ""
        folderPicker.currentFolder = folderAtOpen
        folderPicker.selectedFolder = folderAtOpen
        folderPicker.open()
    }
    function choose(url) {
        if (settings.externalWallpaper && !selectionOnly) return false
        const suffix = url.toString().split("/").pop().split(".").pop().split(/[?#]/)[0].toLowerCase()
        if (!supportedExtensions.includes(suffix)) {
            selectionMessage = "Ese archivo no tiene un formato de imagen compatible."
            return false
        }
        selectionMessage = ""
        try {
            const normalized=WallpaperIdentity.normalize(url)
            if(selectionOnly){imageSelected(normalized);return true}
            if(settings.profileManager) {
                const applied=settings.profileManager.requestWallpaper(normalized)
                if(!applied) {
                    const associations=settings.profileManager.associationManager
                    selectionMessage=associations && associations.pending ? "" : associations ? associations.error : settings.profileManager.error
                }
                return applied
            }
            settings.imageUrl=normalized
            return true
        }catch(e){selectionMessage=String(e.message || e);return false}
    }
    function currentName() {
        const path = WallpaperIdentity.label(settings.activeWallpaper).split("/").pop() || ""
        return path || "Ningún fondo seleccionado"
    }

    FileDialog {
        id: picker
        title: "Elige un fondo de pantalla"
        currentFolder: panel.localUrl(panel.wallpaperFolder)
        nameFilters: ["Imágenes compatibles (*.png *.apng *.jpg *.jpeg *.jpe *.jfif *.bmp *.dib *.gif *.webp *.tif *.tiff *.svg *.svgz *.ico *.icns *.avif *.heic *.heif *.jxl *.jp2 *.j2k *.j2c *.jpf *.jpx *.jpm *.jng *.mng *.dds *.exr *.hdr *.iff *.lbm *.pcx *.pfm *.pic *.pxr *.ras *.rgb *.rgba *.sct *.tga *.tim *.qoi *.psd *.kra *.xcf *.wbmp *.pbm *.pgm *.ppm *.xbm *.xpm *.3fr *.arw *.cr2 *.cr3 *.dcr *.dng *.erf *.fff *.iiq *.k25 *.kdc *.mef *.mos *.mrw *.nef *.nrw *.orf *.pef *.raf *.raw *.rw2 *.rwl *.sr2 *.srf *.srw *.x3f)", "Todos los archivos (*)"]
        onAccepted: panel.choose(selectedFile.toString())
    }

    FolderDialog {
        id: folderPicker
        title: "Elige la carpeta de fondos"
        onAccepted: {
            const selected = selectedFolder.toString()
            const current = currentFolder.toString()
            const chosen = selected && !panel.sameFolder(selected, panel.folderAtOpen) ? selected
                : current && !panel.sameFolder(current, panel.folderAtOpen) ? current
                : selected || current
            if (!chosen) {
                panel.folderMessage = "No se recibió una carpeta del selector. Inténtalo otra vez."
                return
            }
            panel.settings.galleryFolder = chosen
            panel.refreshGallery()
        }
    }

    Process {
        id: galleryScanner
        command: ["python3", Quickshell.shellPath("scripts/wallpaper-gallery.py"), panel.wallpaperFolder]
        stdout: StdioCollector {
            id: galleryOutput
            onStreamFinished: {
                try { panel.gallery = JSON.parse(text) }
                catch (error) { console.warn("No se pudo leer la galería de fondos:", error) }
            }
        }
        Component.onCompleted: panel.refreshGallery()
    }

    Column {
        id: content
        width: parent.width
        spacing: 10
        Text {width:parent.width;wrapMode:Text.WordWrap; text: panel.selectionOnly ? "VINCULAR FONDO · NO CAMBIA EL ESCRITORIO" : "JARDÍN CARMESÍ"; color: "#ed9baa"; font.pixelSize: 11; font.letterSpacing: 2.2; font.weight: Font.DemiBold }
        Rectangle {
            width: parent.width; height: 150; radius: 8; color: "#1d1318"; border.color: "#743044"; clip: true
            Image {
                anchors.fill: parent; source: panel.settings.activeWallpaper ? panel.localUrl(panel.settings.activeWallpaper) : ""
                fillMode: panel.settings.fitMode === "fit" ? Image.PreserveAspectFit
                    : panel.settings.fitMode === "center" ? Image.Pad : Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter; verticalAlignment: Image.AlignVCenter
                asynchronous: true; cache: false
            }
            Rectangle { anchors.fill: parent; color: "black"; opacity: panel.settings.dim }
            Image {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 7
                width: 32
                height: 32
                source: "assets/panel-rose.svg"
                opacity: 0.82
            }
            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: panel.currentName(); color: "white"; font.pixelSize: 11; elide: Text.ElideMiddle
            }
        }
        RoryButton { width: parent.width; objectName:"chooseAndApplyWallpaper"; visible: panel.selectionOnly || !panel.settings.externalWallpaper;text: panel.selectionOnly ? "Elegir imagen para vincular" : "Seleccionar y aplicar wallpaper"; hint: "Abrir selector de archivos"; onClicked: picker.open() }
        Text { visible: !!panel.selectionMessage; width: parent.width; text: panel.selectionMessage; color: "#ff9aab"; font.pixelSize: 11; wrapMode: Text.WordWrap }
        RowLayout {
            width: parent.width
            Text { Layout.fillWidth: true; text: "Carpeta de fondos"; color: "#eadde1"; font.pixelSize: 14; font.family: "Liberation Serif"; elide: Text.ElideMiddle }
            RoryButton { text: "Elegir"; hint: "Seleccionar carpeta de fondos"; onClicked: panel.openFolderPicker() }
            RoryButton { text: "↻"; hint: "Volver a explorar esta carpeta"; onClicked: panel.refreshGallery() }
        }
        Text {
            visible: !!panel.folderMessage
            width: parent.width
            text: panel.folderMessage
            color: "#ff9aab"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: panel.wallpaperFolder
            color: "#9e8791"
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
        GridLayout {
            width: parent.width; columns: 3; rowSpacing: 7; columnSpacing: 7
            Repeater {
                model: panel.gallery
                delegate: Item {
                    id: wallpaperThumb
                    required property string modelData
                    readonly property string imagePath: modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 61
                    Rectangle {
                        anchors.fill: parent; radius: 6; color: "#21151b"
                        border.width: panel.settings.activeWallpaper && panel.localUrl(panel.settings.activeWallpaper) === panel.localUrl(parent.imagePath) ? 2 : 1
                        border.color: panel.settings.activeWallpaper && panel.localUrl(panel.settings.activeWallpaper) === panel.localUrl(parent.imagePath) ? "#f05b78" : "#693044"
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 2
                            source: panel.localUrl(wallpaperThumb.imagePath); fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            enabled: panel.selectionOnly || !panel.settings.externalWallpaper
                            objectName:"applyWallpaperThumbnail";onClicked: panel.choose(panel.localUrl(wallpaperThumb.imagePath))
                        }
                    }
                }
            }
        }
        Text {
            visible: panel.gallery.length === 0
            width: parent.width
            text: "No hay imágenes compatibles directamente en esta carpeta."
            color: "#b99da8"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
        Column {width:parent.width;spacing:10;visible:!panel.selectionOnly
        StudioButton {objectName:"configureWallpaper";visible:panel.showStudioActions;width:parent.width;text:"Configurar wallpaper";onClicked:panel.showConfiguration=!panel.showConfiguration}
        Loader {width:parent.width;active:panel.showConfiguration;visible:active;sourceComponent:WallpaperConfigurationPanel {settings:panel.settings}}
        StudioButton {objectName:"linkWallpaperProfiles";width:parent.width;visible:panel.showStudioActions && panel.settings.studioController!==null;text:"Vincular perfiles al wallpaper";onClicked:panel.settings.studioController.open("associations",null)}
        PanelRule {visible:panel.showStudioActions}
        Text {visible:panel.showStudioActions; text: "Composición del escritorio"; color: "#eddae4"; font.pixelSize:16 }
        Text {visible:panel.showStudioActions;width:parent.width;wrapMode:Text.WordWrap;color:"#b99da8";font.pixelSize:11;text:panel.settings.visualizerStatus || "El visualizador funciona con cualquier fondo. Color, estilos y efectos se ajustan por capa en el editor."}
        Text {
            width: parent.width
            text: "El fondo se aplica al elegirlo y se conserva al reiniciar Rory."
            color: "#9e8791"; font.pixelSize: 10; wrapMode: Text.WordWrap
        }
        }
    }
}
