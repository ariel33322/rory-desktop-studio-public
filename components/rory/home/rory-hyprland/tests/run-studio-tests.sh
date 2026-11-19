#!/bin/sh
# Production settings/history/profile managers, isolated INIs, no service operations.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/rory-studio-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$project/"*.qml "$project/"*.js "$test_dir/"
for directory in audio-layers audio-particles visualizer-layers studio-profiles; do
    cp -R "$project/$directory" "$test_dir/"
done
cp "$project/tests/tst_studio.qml" "$test_dir/shell.qml"
# The production reader needs a valid legacy INI. Audio stays in test mode.
cat > "$test_dir/.wallpaper-settings.ini" <<'INI'
[RoryWallpaper]
visualizerEnabled=false
visualizerTestMode=true
INI
mkdir "$test_dir/runtime"
chmod 700 "$test_dir/runtime"
for test in test_associations test_restart; do
    status=0
    env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR="$test_dir/runtime" QT_QPA_PLATFORM=offscreen RORY_STUDIO_TEST="$test" timeout 15 qs --no-color -p "$test_dir/shell.qml" > "$test_dir/output.log" 2>&1 || status=$?
    cat "$test_dir/output.log"
    if [ "$status" -ne 0 ]; then exit "$status"; fi
    if ! rg -q STUDIO_TEST_PASS "$test_dir/output.log" || rg -q 'STUDIO_TEST_FAIL|Failed to load configuration' "$test_dir/output.log"; then
        exit 1
    fi
done
