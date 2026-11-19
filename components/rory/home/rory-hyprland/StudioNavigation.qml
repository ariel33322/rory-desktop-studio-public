pragma ComponentBehavior: Bound
import QtQuick

StudioCombo {
    id: navigation
    required property var studio
    required property var targetScreen
    required property string destination
    objectName: "studioNavigation"
    visible: studio !== null
    Accessible.name: "Secciones de Rory Desktop Studio"
    model: studio ? studio.destinations : []
    textRole: "title"
    currentIndex: model.findIndex(entry => entry.id === destination)
    onActivated: index => {
        studio.open(model[index].id, targetScreen)
        currentIndex = Qt.binding(() => model.findIndex(entry => entry.id === destination))
    }
}
