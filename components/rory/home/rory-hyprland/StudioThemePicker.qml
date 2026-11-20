pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "RoryTheme.js" as Theme

RowLayout {
    id:picker
    required property string title
    required property string theme
    property bool allowGlobal:false
    signal chosen(string value)
    Layout.fillWidth:true
    Label {Layout.fillWidth:true;text:picker.title;color:"#eadce5";wrapMode:Text.WordWrap}
    StudioCombo {
        readonly property var ids:picker.allowGlobal ? ["",...Theme.ids] : Theme.ids
        Layout.preferredWidth:160
        model:picker.allowGlobal ? ["Tema global",...Theme.names] : Theme.names
        currentIndex:Math.max(0,ids.indexOf(picker.theme))
        onActivated:index=>{
            picker.chosen(ids[index])
            currentIndex=Qt.binding(()=>Math.max(0,ids.indexOf(picker.theme)))
        }
    }
}
