pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Scope {
    id: host
    required property var store
    required property var studio
    required property var services
    required property var coverage
    Variants {
        reloadableId:"taskbarScreens"
        model: host.store.bars.some(b=>b.enabled) ? Quickshell.screens : []
        Scope {
            id: outputBars
            required property ShellScreen modelData
            Variants {
                model: host.store.bars.filter(b=>b.enabled && (!b.output || b.output===outputBars.modelData.name)).map(b=>b.id)
                Scope {
                    id: instance
                    required property string modelData
                    TaskbarPanel {
                        barId:instance.modelData
                        output:outputBars.modelData
                        store:host.store
                        studio:host.studio
                        services:host.services
                        coverage:host.coverage
                    }
                }
            }
        }
    }
}
