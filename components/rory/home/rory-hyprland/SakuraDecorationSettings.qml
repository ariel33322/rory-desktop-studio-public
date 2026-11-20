pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import "SakuraDecoration.js" as Sakura

Item {
    id:settings
    width:0;height:0;visible:false
    required property url storagePath
    readonly property var config: {
        try {return saved.data ? Sakura.read(saved.data) : Sakura.defaults()}
        catch (_) {return Sakura.defaults()}
    }
    property string error:""
    function edit(key,value) {
        try {
            const current=saved.data ? Sakura.read(saved.data) : Sakura.defaults()
            saved.data=JSON.stringify(Sakura.read(Object.assign(current,{[key]:value})))
            error=""
            return true
        } catch(e){error=String(e.message || e);return false}
    }
    Settings {
        id:saved
        location:settings.storagePath
        category:"RoryBarSakuraDecoration"
        property string data:""
    }
}
