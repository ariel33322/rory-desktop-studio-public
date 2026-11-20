#!/bin/sh
# Only the fixture lives in the temporary directory. Qt paints production QML.
set -eu
case "${1:-}" in
    ""|--no-bar-draw) ;;
    *) printf 'Usage: %s [--no-bar-draw]\n' "$0" >&2; exit 2 ;;
esac

project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/rory-render-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$project/"*.js "$project/RadialSpectrum.qml" "$project/BarSilence.qml" "$test_dir/"
for directory in art audio-layers audio-particles visualizer-layers; do
    cp -R "$project/$directory" "$test_dir/"
done
cp "$project/tests/tst_bar_render.qml" "$test_dir/"
# Quickshell registers its FileView plugin in qs, not in qmltestrunner.
# This fixture uses V2 layers directly, so supply an empty legacy reader.
cat > "$test_dir/visualizer-layers/LegacySettingsReader.qml" <<'QML'
import QtQml
QtObject {
    readonly property var values: ({})
    readonly property string error: ""
}
QML
mkdir -m 700 "$test_dir/runtime"

if [ "${1:-}" = --no-bar-draw ]; then
    python3 - "$test_dir/RadialSpectrum.qml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
guard = "if (fade <= 0) return"
if source.count(guard) != 1:
    raise SystemExit("Mutation requires exactly one bar-opacity guard")
path.write_text(source.replace(guard, "if (fade >= 0) return", 1))
PY
fi

env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    XDG_RUNTIME_DIR="$test_dir/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=1 \
    timeout 30 /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/tst_bar_render.qml"
