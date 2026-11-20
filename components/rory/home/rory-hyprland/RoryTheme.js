.pragma library

const names=["Crimson Original","Sakura Pink"]
const ids=["crimson","sakura"]
const cherry="#FF5B9A"
const fuchsia="#F02F7E"
const pale="#FF9DC3"
const plum="#25101E"
const dark="#120B14"
const text="#F7C7DA"

function valid(value) {return ids.includes(value)}
function tone(theme, crimson, sakura) {return theme==="sakura" ? sakura : crimson}
function art(theme,name) {return "art/"+(theme==="sakura" ? "sakura-" : "")+name+".svg"}
function center(config) {
    if(config.theme!=="sakura")return config
    return Object.assign({},config,{width:config.sakuraLayout?.width ?? (config.width>=410 ? 390 : config.width),
        spacing:config.sakuraLayout?.spacing ?? (config.spacing===12 ? 8 : config.spacing),background:dark,border:cherry,accent:fuchsia},config.sakuraColors)
}
function taskbar(config) {
    if(config.theme!=="sakura")return config
    return Object.assign({},config,{background:dark,border:cherry,iconColor:pale,textColor:text,activeColor:"#683049"},config.sakuraColors)
}
