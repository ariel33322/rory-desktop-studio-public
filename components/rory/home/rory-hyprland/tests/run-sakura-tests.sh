#!/bin/sh
set -eu
project=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
trial=$(mktemp -d /tmp/rory-sakura-tests.XXXXXX)
trap 'rm -rf -- "$trial"' EXIT
mkdir "$trial/art"
cp "$project"/SakuraBranch.qml "$project"/SakuraMotion.qml "$project"/SakuraPetalField.qml \
   "$project"/SakuraDecoration.js "$project"/SakuraDecorationSettings.qml \
   "$project"/tests/tst_sakura.qml "$trial/"
cp "$project"/art/sakura-blossom.svg "$project"/art/sakura-petal-fall.svg \
   "$project"/art/sakura-floral-leaf.svg "$trial/art/"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_CONFIG_HOME="$trial"
runner=${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}
"$runner" -input "$trial/tst_sakura.qml" SakuraDecoration::test_limits SakuraDecoration::test_cycles
"$runner" -input "$trial/tst_sakura.qml" SakuraDecoration::test_restart
