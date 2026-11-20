#!/bin/sh
# Start this isolated preview with a fresh directory from mktemp -d.
set -eu
if [ "$#" -ne 1 ] || [ ! -d "$1" ] || [ -L "$1" ]; then
    printf '%s\n' 'Uso: sh tests/run-taskbar-wayland.sh DIRECTORIO_TEMPORAL' >&2
    exit 2
fi
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(CDPATH= cd -- "$1" && pwd -P)
case "$scratch" in /tmp/rory-barra.*) ;; *) exit 2 ;; esac
if [ ! -f "$scratch/.rory-taskbar-preview" ]; then
    if [ -n "$(find "$scratch" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        printf '%s\n' 'La primera ejecución requiere un directorio temporal vacío.' >&2
        exit 2
    fi
    umask 077
    cp "$project/"*.qml "$project/"*.js "$scratch/"
    for dir in audio-layers audio-particles visualizer-layers studio-profiles assets art; do
        cp -R "$project/$dir" "$scratch/"
    done
    cp "$project/tests/taskbar-wayland.qml" "$scratch/shell.qml"
    mkdir "$scratch/scripts"
    cp "$project/scripts/crimson-control.py" "$project/scripts/battery-metrics.py" "$project/scripts/bluetooth-agent.py" "$scratch/scripts/"
    printf '[RoryWallpaper]\nvisualizerEnabled=false\nvisualizerTestMode=true\n' > "$scratch/.wallpaper-settings.ini"
    touch "$scratch/.rory-taskbar-preview"
fi
exec qs -n -p "$scratch/shell.qml"
