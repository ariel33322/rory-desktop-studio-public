#!/bin/sh
# Real production panels in a Qt window offscreen; all data lives in /tmp.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$project/tests/run-render-tests.sh"
test_dir=$(mktemp -d /tmp/rory-regression-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$project/"*.qml "$project/"*.js "$test_dir/"
for directory in audio-layers audio-particles visualizer-layers studio-profiles scripts assets; do
    cp -R "$project/$directory" "$test_dir/"
done
cp "$project/tests/tst_regressions.qml" "$test_dir/shell.qml"
cp "$project/tests/tst_bar_silence.qml" "$test_dir/"
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/tst_bar_silence.qml"
# Keep the production clock and its input handlers. Replace only the native
# panel wrapper in the temporary copy so Qt can construct it offscreen.
python3 - "$test_dir/ClockWidget.qml" <<'PY_QML'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text().replace("import QtQuick\n", "import QtQuick\nimport QtQuick.Window\n", 1)
source = source.replace("PanelWindow {", "Window {", 1)
source = source.replace("    screen: modelData", "    width: modelData.width; height: modelData.height", 1)
start = source.index("    anchors { top: true;")
end = source.index("    property date now:", start)
path.write_text(source[:start] + '    color: "transparent"\n\n' + source[end:])
PY_QML
mkdir "$test_dir/runtime" "$test_dir/wallpapers"
chmod 700 "$test_dir/runtime"
cat > "$test_dir/.wallpaper-settings.ini" <<INI
[RoryWallpaper]
visualizerEnabled=false
visualizerTestMode=true
galleryFolder=file://$test_dir/wallpapers
INI
python3 - "$test_dir/wallpapers/linked.png" <<'PY_FIXTURE'
import struct,sys,zlib
from pathlib import Path
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
Path(sys.argv[1]).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0'+b'\xff\0\0'*2+b'\0'+b'\xff\0\0'*2))+chunk(b'IEND',b''))
PY_FIXTURE
for phase in exercise restart; do
    status=0
    env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR="$test_dir/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software RORY_REGRESSION_PHASE="$phase" timeout 20 qs --no-color -p "$test_dir/shell.qml" > "$test_dir/output.log" 2>&1 || status=$?
    cat "$test_dir/output.log"
    if [ "$status" -ne 0 ]; then exit "$status"; fi
    if ! rg -q REGRESSION_TEST_PASS "$test_dir/output.log" || rg -q 'REGRESSION_TEST_FAIL|Failed to load configuration|ReferenceError|TypeError|Binding loop' "$test_dir/output.log"; then exit 1; fi
done
