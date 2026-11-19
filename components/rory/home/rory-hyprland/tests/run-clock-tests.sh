#!/bin/sh
# Exercise production components in an isolated directory; never touch live INIs.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/rory-clock-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$project/ClockOutlineText.qml" "$project/ClockPointerEdit.qml" "$project/ClockSettings.qml" "$project/ClockProfileManager.qml" "$project/StudioProfiles.js" "$project/WallpaperIdentity.js" "$test_dir/"
for component in StudioProfileBar StudioCombo StudioField StudioButton StudioToolButton StudioMenu StudioMenuItem StudioColorEditor StudioSection VisualizerSlider; do
    cp "$project/$component.qml" "$test_dir/"
done
cp "$project/tests/tst_clock.qml" "$test_dir/"
cat > "$test_dir/.clock-settings.ini" <<'INI'
[RoryClock]
timeSize=127
leftPercent=0.12
topPercent=0.38
opacity=0.91
INI
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/tst_clock.qml" ClockProfiles::test_profiles
# A second Qt process checks actual Settings persistence after shutdown.
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/tst_clock.qml" ClockProfiles::test_restart
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/tst_clock.qml" ClockProfiles::test_draftRestart
