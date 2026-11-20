pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "TaskbarModel.js" as Model

Scope {
    id: coordinator
    required property SystemState services
    property var owner: null
    property ShellScreen output: null
    property bool opened: false
    readonly property var window: surface.item
    readonly property bool visible: opened && owner !== null
    onOutputChanged: if(!output) {
        window?.stopFlash()
        close()
        owner=null
    }

    function openFor(source) {
        if (!source.crimsonConfig.enabled || !source.crimsonOutput) return
        // The white surface must stay on the monitor whose brightness lease it owns.
        if (window?.flashlightBusy && output !== source.crimsonOutput) return
        services.panelOwner?.closePanel()
        output=source.crimsonOutput
        owner=source
        opened=true
        if (!surface.source.toString()) {
            surface.setSource("CrimsonCenter.qml", {
                output:Qt.binding(()=>coordinator.output),
                config:Qt.binding(()=>coordinator.owner?.crimsonConfig ?? Model.centerDefaults()),
                services:coordinator.services,
                open:Qt.binding(()=>coordinator.visible),
                anchorY:Qt.binding(()=>coordinator.owner?.crimsonAnchorY ?? 0),
                rightInset:Qt.binding(()=>coordinator.owner?.crimsonRightInset ?? 12),
                closeRequest:()=>coordinator.close(),
                legacyDetails:Qt.binding(()=>typeof coordinator.owner?.openCrimsonDetail==="function"),
                legacyRequest:page=>coordinator.owner?.openCrimsonDetail?.(page)
            })
        }
        if (surface.status===Loader.Error) close()
    }
    function close() { opened=false }
    function release(source) {
        if(owner!==source)return
        window?.stopFlash()
        close()
        owner=null
    }
    Connections {
        target:Quickshell
        function onScreensChanged() {
            if(coordinator.output && !Quickshell.screens.includes(coordinator.output)) {
                coordinator.window?.stopFlash()
                coordinator.close()
                coordinator.owner=null
                coordinator.output=null
            }
        }
    }
    Loader {
        id:surface
        onStatusChanged:if(status===Loader.Error)coordinator.close()
    }
}
