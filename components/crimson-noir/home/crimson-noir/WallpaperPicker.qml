pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import Qt.labs.folderlistmodel

Rectangle {
    id: picker

    signal chosen(url file)
    signal dismissed()

    radius: 34
    color: "#140d16"

    FolderListModel {
        id: images
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirsFirst: true
        showOnlyReadable: true
    }

    MouseArea { anchors.fill: parent }

    Column {
        anchors.fill: parent
        anchors.margins: 17
        anchors.topMargin: 35
        spacing: 12

        Item {
            width: parent.width
            height: 32
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Cambiar fondo"
                color: "#e44b65"
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: "white"
                font.pixelSize: 20
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: picker.dismissed()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 12
            color: "#27202a"
            border.color: "#744050"
            Text {
                anchors.fill: parent
                anchors.margins: 10
                verticalAlignment: Text.AlignVCenter
                text: "↑  Carpeta superior"
                color: "#fff1f4"
                font.pixelSize: 13
            }
            MouseArea {
                anchors.fill: parent
                enabled: images.parentFolder.toString() !== ""
                onClicked: images.folder = images.parentFolder
            }
        }

        Text {
            width: parent.width
            height: 18
            text: decodeURI(images.folder.toString().replace(/^file:\/\//, ""))
            color: "#db9caa"
            font.pixelSize: 11
            elide: Text.ElideLeft
        }

        ListView {
            width: parent.width
            height: parent.height - 126
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: images

            delegate: Rectangle {
                id: fileRow
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                width: ListView.view.width
                height: 42
                radius: 8
                color: fileMouse.containsMouse ? "#40202b" : "transparent"
                Text {
                    anchors.fill: parent
                    anchors.margins: 9
                    verticalAlignment: Text.AlignVCenter
                    text: (fileRow.fileIsDir ? "▸  " : "") + fileRow.fileName
                    color: "#fff1f4"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (fileRow.fileIsDir) images.folder = fileRow.fileUrl
                        else picker.chosen(fileRow.fileUrl)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: images.status === FolderListModel.Ready && images.count === 0
                text: "No hay imágenes en esta carpeta"
                color: "#a5a0a7"
                font.pixelSize: 13
            }
        }
    }
}
