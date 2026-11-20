pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id:branch
    required property bool rightBranch
    required property real growth
    required property real sway
    width:rightBranch ? 174 : 226
    height:rightBranch ? 78 : 104
    enabled:false
    visible:growth>0
    transform:Rotation {origin.x:branch.rightBranch ? branch.width : 0;origin.y:0;angle:branch.sway}
    readonly property var paths:rightBranch ? [
        "M 174 3 C 151 7 141 18 122 29 C 98 45 72 43 50 53 C 37 59 25 58 15 64",
        "M 133 22 C 114 21 110 11 93 13 C 86 13 80 16 76 20",
        "M 114 34 C 105 47 103 55 91 67",
        "M 77 46 C 67 38 57 31 42 34",
        "M 52 53 C 47 62 40 71 27 72"
    ] : [
        "M 0 4 C 24 10 39 17 60 27 C 84 43 117 43 137 55 C 161 72 186 76 211 77",
        "M 48 22 C 66 17 75 6 91 12 C 98 14 104 17 110 18",
        "M 72 34 C 82 51 73 66 93 82 C 99 87 104 92 110 94",
        "M 113 45 C 131 41 144 31 169 35",
        "M 153 66 C 157 78 167 90 183 93"
    ]
    // Each arrangement is drawn separately. The points follow the forks above.
    readonly property var flowers:rightBranch ? [
        [152,10,12,11,.15],[136,20,18,-23,.24],[115,18,13,43,.31],
        [98,12,9,-10,.35],[124,30,20,24,.39],[102,40,14,52,.45],
        [91,66,13,-18,.54],[76,44,17,-9,.54],[49,35,11,29,.57],
        [51,54,15,46,.63],[28,71,9,-12,.73],[18,63,8,31,.79]
    ] : [
        [22,11,11,-18,.12],[37,17,17,22,.18],[55,24,22,7,.25],
        [72,17,13,-33,.28],[87,12,10,43,.36],[106,17,12,12,.42],
        [79,36,19,-14,.43],[101,39,15,24,.47],[83,59,13,63,.54],
        [104,88,12,12,.69],[126,47,21,38,.57],[145,49,14,-25,.62],
        [166,35,11,43,.64],[159,69,18,19,.68],[183,92,10,-37,.76],[207,77,9,12,.78]
    ]
    readonly property var leaves:rightBranch ? [[147,15,-23],[106,35,20],[40,58,49]] : [[70,28,22],[121,46,59],[181,73,78]]
    readonly property var buds:rightBranch ? [[76,19,35],[14,64,-29]] : [[110,17,-35],[112,94,-18],[211,76,61]]
    function phase(begin,span) {return Math.max(0,Math.min(1,(growth-begin)/span))}
    function spawningPoint(index) {
        const picked=flowers[(index*3+2)%flowers.length]
        return Qt.point(picked[0],picked[1]+picked[2]*.22)
    }

    Shape {
        anchors.fill:parent
        preferredRendererType:Shape.CurveRenderer
        ShapePath {
            strokeColor:"#32131F";strokeWidth:3.2;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(0,.79)
            PathSvg {path:branch.paths[0]}
        }
        ShapePath {
            strokeColor:"#6C3148";strokeWidth:.68;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(0,.79)
            PathSvg {path:branch.paths[0]}
        }
        ShapePath {
            strokeColor:"#543043";strokeWidth:1.45;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(.12,.64)
            PathSvg {path:branch.paths[1]}
        }
        ShapePath {
            strokeColor:"#593044";strokeWidth:1.4;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(.22,.58)
            PathSvg {path:branch.paths[2]}
        }
        ShapePath {
            strokeColor:"#593044";strokeWidth:1.1;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(.29,.57)
            PathSvg {path:branch.paths[3]}
        }
        ShapePath {
            strokeColor:"#593044";strokeWidth:1;fillColor:"transparent";capStyle:ShapePath.RoundCap
            trim.end:branch.phase(.39,.57)
            PathSvg {path:branch.paths[4]}
        }
    }
    Repeater {
        model:branch.leaves
        Image {
            required property var modelData
            width:8;height:13;x:modelData[0]-width/2;y:modelData[1]-height
            rotation:modelData[2]
            transformOrigin:Item.Bottom
            source:"art/sakura-floral-leaf.svg"
            opacity:branch.phase(.42,.35)*.45
            visible:opacity>0
        }
    }
    Repeater {
        model:branch.buds
        Rectangle {
            required property var modelData
            width:4;height:7;radius:2
            x:modelData[0]-width/2;y:modelData[1]-height/2
            rotation:modelData[2]
            color:"#D45380";border.color:"#FF9DC3";border.width:.4
            opacity:branch.phase(.47,.35)
            visible:opacity>0
        }
    }
    Repeater {
        model:branch.flowers
        Image {
            required property var modelData
            required property int index
            readonly property real bloom:branch.phase(modelData[4],.21)
            width:modelData[2];height:width
            x:modelData[0]-width/2;y:modelData[1]-height/2
            rotation:modelData[3]-(1-bloom)*8
            scale:.53+.47*bloom
            opacity:bloom*(index%4===1 ? .77 : 1)
            mirror:index%3===0
            source:"art/sakura-blossom.svg"
            sourceSize:Qt.size(Math.ceil(modelData[2]*2),Math.ceil(modelData[2]*2))
            visible:bloom>0
        }
    }
}
