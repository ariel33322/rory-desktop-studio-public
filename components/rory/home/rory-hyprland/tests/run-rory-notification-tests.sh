#!/bin/sh
set -eu
project=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
trial=$(mktemp -d /tmp/rory-notif.XXXXXX)
trap 'rm -rf -- "$trial"' EXIT
mkdir -m 700 "$trial/runtime"
cp "$project"/*.qml "$project"/*.js "$trial/"
cp "$project/tests/tst_rory_notifications.qml" "$trial/shell.qml"
ln -s "$project/assets" "$trial/assets"
ln -s "$project/art" "$trial/art"
ln -s "$project/scripts" "$trial/scripts"
for directory in audio-layers audio-particles visualizer-layers studio-profiles; do
    ln -s "$project/$directory" "$trial/$directory"
done
python3 - "$trial/RoryBar.qml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text().replace('PanelWindow {', 'Window {')
a = s.index('    screen: modelData')
b = s.index('    readonly property int bodyHeight', a)
s = s[:a] + '    width: 800; height: 200; visible: true\n' + s[b:]
a = s.index('    HyprlandFocusGrab {')
b = s.index('    Window {', a)
s = s[:a] + '    QtObject { id: panelGrab; property bool active: false }\n' + s[b:]
a = s.index('        screen: bar.screen')
b = s.index('        onVisibleChanged:', a)
s = s[:a] + '        property bool backingWindowVisible: false\n' + s[b:]
a = s.index('        mask: Region')
b = s.index('        color:', a)
s = s[:a] + '        width: controlCard.implicitWidth; height: controlCard.implicitHeight + 8\n' + s[b:]
p.write_text(s)
PY
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DBUS_SESSION_BUS_ADDRESS \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$trial/runtime/unavailable" \
    XDG_RUNTIME_DIR="$trial/runtime" XDG_CACHE_HOME="$trial" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15 qs --no-color -p "$trial/shell.qml" >"$trial/result" 2>&1 || {
    cat "$trial/result"; exit 1;
}
cat "$trial/result"
rg -q RORY_NOTIFICATION_TEST_PASS "$trial/result"
! rg -q 'RORY_NOTIFICATION_TEST_FAIL|TypeError|ReferenceError|Binding loop|Cannot assign' "$trial/result"
