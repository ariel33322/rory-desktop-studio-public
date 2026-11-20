#!/bin/sh
# Isolate settings and replace only the native panel wrapper in the test copy.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/rory-taskbars.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cp "$project/"*.qml "$project/"*.js "$scratch/"
for dir in art audio-layers audio-particles visualizer-layers studio-profiles; do
    cp -R "$project/$dir" "$scratch/"
done
cp "$project/tests/tst_taskbars.qml" "$scratch/shell.qml"
python3 - "$scratch/TaskbarPanel.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text().replace("PanelWindow {", "Window {", 1)
start = text.index("    screen:output")
end = text.index("    onEditingChanged:", start)
p.write_text(text[:start] + '    width:800; height:600; visible:true\n' + text[end:])
PY
printf '[RoryWallpaper]\nvisualizerEnabled=false\nvisualizerTestMode=true\n' > "$scratch/.wallpaper-settings.ini"
mkdir -m 700 "$scratch/runtime"
for phase in exercise restart; do
    env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR="$scratch/runtime" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software RORY_TASKBAR_PHASE="$phase" \
        timeout 15 qs --no-color -p "$scratch/shell.qml" > "$scratch/output" 2>&1 || {
        cat "$scratch/output"; exit 1;
    }
    cat "$scratch/output"
    rg -q 'TASKBAR_TEST_PASS' "$scratch/output"
    if rg -q 'TASKBAR_TEST_FAIL|TypeError|ReferenceError|Binding loop|Cannot assign' "$scratch/output"; then exit 1; fi
done
