pragma ComponentBehavior: Bound
import QtQuick
import "RoryTheme.js" as Theme

// Original 24px line drawings. The small petal is the common accent.
Canvas {
    id:icon
    required property string kind
    property bool selected:false
    property bool usable:true
    readonly property color ink:!usable ? "#A88499" : selected ? Theme.cherry : Theme.pale
    onKindChanged:requestPaint()
    onInkChanged:requestPaint()
    onWidthChanged:requestPaint()
    onHeightChanged:requestPaint()
    onPaint:{
        const c=getContext("2d")
        c.reset();c.clearRect(0,0,width,height)
        const size=Math.min(width,height)
        c.translate((width-size)/2,(height-size)/2);c.scale(size/24,size/24)
        c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1.55;c.lineCap="round";c.lineJoin="round"
        function path(points,close=false) {
            c.beginPath();c.moveTo(points[0],points[1])
            for(let i=2;i<points.length;i+=2)c.lineTo(points[i],points[i+1])
            if(close)c.closePath()
            c.stroke()
        }
        function ring(x,y,r){c.beginPath();c.arc(x,y,r,0,2*Math.PI);c.stroke()}
        function arc(x,y,r,start,end){c.beginPath();c.arc(x,y,r,start,end);c.stroke()}
        function petal(x,y){
            c.beginPath();c.moveTo(x-1.7,y+1.7)
            c.quadraticCurveTo(x-2.2,y-.7,x+1.7,y-1.7)
            c.quadraticCurveTo(x+2.2,y+.7,x-1.7,y+1.7);c.fill()
        }
        switch(kind){
        case "wifi":
            for(const r of [10,7,4])arc(12,17,r,3.9,5.53)
            petal(12,17);break
        case "bluetooth":
            path([6,6,17,16,12,20,12,4,17,8,6,18]);break
        case "brightness":
            ring(12,12,4.1)
            for(let i=0;i<8;i++){
                const a=i*Math.PI/4
                path([12+Math.cos(a)*7,12+Math.sin(a)*7,12+Math.cos(a)*9.5,12+Math.sin(a)*9.5])
            }
            petal(12,12);break
        case "volume": case "muted":
            path([3,9,7,9,12,5,12,19,7,15,3,15],true)
            if(kind==="muted"){path([16,9,21,15]);path([21,9,16,15])}
            else {arc(12,12,4,-.7,.7);arc(12,12,7,-.7,.7)}
            break
        case "kde":
            c.beginPath();c.rect(7,2.5,10,19);c.stroke()
            path([10,5,14,5]);petal(12,18);break
        case "airplane":
            path([12,3,14,9,21,13,21,15,14,13,14,17,16,19,16,20,12,19,8,20,8,19,10,17,10,13,3,15,3,13,10,9],true);break
        case "dnd":
            c.beginPath();c.moveTo(5,16);c.lineTo(7,13);c.lineTo(7,9)
            c.bezierCurveTo(7,3,17,3,17,9);c.lineTo(17,13);c.lineTo(19,16);c.closePath();c.stroke()
            petal(12,20);break
        case "power": path([13,3,6,13,11,13,10,21,18,10,13,10,13,3]);break
        case "record": ring(12,12,8.5);ring(12,12,5);petal(12,12);break
        case "night":
            c.beginPath();c.moveTo(16,4);c.bezierCurveTo(7,2,3,8,5,15)
            c.bezierCurveTo(7,21,16,22,20,15);c.bezierCurveTo(12,17,9,9,16,4)
            c.stroke();petal(19,7);break
        case "capture":
            path([4,9,4,4,9,4]);path([15,4,20,4,20,9])
            path([20,15,20,20,15,20]);path([9,20,4,20,4,15])
            petal(12,12);break
        case "settings":
            ring(12,12,3)
            path([10,3,14,3,15,6,18,8,21,8,21,12,18,14,17,17,18,20,14,21,12,19,9,19,7,21,4,19,5,16,4,13,2,11,3,8,6,8,8,6],true);break
        case "flash":
            path([5,4,19,4,19,7,15,12,15,21,9,21,9,12,5,7],true)
            path([5,7,19,7]);petal(12,15);break
        case "music":
            path([9,17,9,7,18,4,18,15]);path([9,9,18,6]);ring(6.5,17.5,2.5);ring(15.5,15.5,2.5);break
        case "play": path([8,5,19,12,8,19],true);break
        case "pause": path([9,5,9,19]);path([15,5,15,19]);break
        case "previous": path([17,5,7,12,17,19],true);path([5,5,5,19]);break
        case "next": path([7,5,17,12,7,19],true);path([19,5,19,19]);break
        case "shuffle":
            path([4,7,7,7,16,17,20,17,17,14]);path([17,20,20,17])
            path([4,17,7,17,16,7,20,7,17,4]);path([17,10,20,7]);break
        case "repeat":
            path([5,10,5,6,19,6,16,3]);path([16,9,19,6])
            path([19,14,19,18,5,18,8,15]);path([8,21,5,18]);break
        case "back": path([15,5,8,12,15,19]);break
        }
    }
}
