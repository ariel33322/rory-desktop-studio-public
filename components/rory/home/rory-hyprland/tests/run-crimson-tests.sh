#!/bin/sh
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/rory-crimson-tests.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cp "$project/"*.qml "$project/"*.js "$scratch/"
for dir in assets art audio-layers audio-particles visualizer-layers studio-profiles; do
    cp -R "$project/$dir" "$scratch/"
done
cp "$project/tests/tst_crimson.qml" "$scratch/shell.qml"
mkdir -m 700 "$scratch/runtime" "$scratch/scripts"
# Rendering tests never write hardware. Their helper provides only a mock lease.
cat > "$scratch/scripts/crimson-control.py" <<'PY'
import sys
if sys.argv[1] == 'flash':
    print('READY', flush=True)
    sys.stdin.readline()
elif sys.argv[1] == 'brightness-check':
    print('{"level":0.6,"method":"sysfs","reason":""}')
elif sys.argv[1] == 'brightness-read':
    print('{"level":0.6}')
else:
    print('{}')
PY
python3 - "$scratch" <<'PY'
from pathlib import Path
import re, sys
base = Path(sys.argv[1])
for filename in ('TaskbarPanel.qml', 'CrimsonCenter.qml', 'RoryBar.qml'):
    p = base / filename
    source = p.read_text().replace('PanelWindow {', 'Window {')
    if filename == 'TaskbarPanel.qml':
        start = source.index('    screen:output')
        end = source.index('    onEditingChanged:', start)
        source = source[:start] + '    width:800; height:600; visible:true\n' + source[end:]
    elif filename == 'RoryBar.qml':
        start = source.index('    screen: modelData')
        end = source.index('    readonly property int bodyHeight', start)
        source = source[:start] + '    width:800; height:200; visible:true\n' + source[end:]
        start = source.index('    HyprlandFocusGrab {')
        end = source.index('    Window {', start)
        source = source[:start] + '    QtObject {id:panelGrab;property bool active:false}\n' + source[end:]
        start = source.index('        screen: bar.screen')
        end = source.index('        onVisibleChanged:', start)
        source = source[:start] + '        property bool backingWindowVisible:false\n        property real implicitWidth:controlCard.implicitWidth\n        property real implicitHeight:controlCard.implicitHeight+8\n' + source[end:]
        source = re.sub(r'^        (?:mask: Region .*|implicitWidth:.*|implicitHeight:.*)$', '', source, flags=re.M)
    else:
        source = re.sub(r'^\s*(?:screen:.*|anchors \{top:true;bottom:true;left:true;right:true\}|exclusionMode:.*|WlrLayershell\..*|mask:Region .*?)$', '', source, flags=re.M)
        # Keep the Qt wrapper exposed for layout polish during rapid open/close tests.
        source = source.replace('    visible:open || card.opacity>0', '    visible:true')
        source = source.replace('    id: center', '    id: center\n    width:800;height:700; transientParent:null')
        source = source.replace('        id:torch', '        id:torch\n        width:800;height:600')
    p.write_text(source)
PY
for phase in exercise restart; do
    env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DBUS_SESSION_BUS_ADDRESS \
        DBUS_SYSTEM_BUS_ADDRESS="unix:path=$scratch/runtime/no-system-bus" \
        XDG_RUNTIME_DIR="$scratch/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software RORY_CRIMSON_PHASE="$phase" \
        timeout 20 qs --no-color -p "$scratch/shell.qml" > "$scratch/output" 2>&1 || {
        cat "$scratch/output"; exit 1;
    }
    cat "$scratch/output"
    rg -q CRIMSON_TEST_PASS "$scratch/output"
    if rg -q 'CRIMSON_TEST_FAIL|TypeError|ReferenceError|Binding loop|Cannot assign' "$scratch/output"; then exit 1; fi
done
